"""
End-to-end demo of the modified salting technique against ScyllaDB.

The demo exercises three blob sizes following the hybrid policy proposed in
the blog post:

* a small blob written without chunking (``max_salt=1``)
* a medium blob spread across a handful of salts
* a large blob spread across many salts to maximise shard parallelism

For every case we round-trip the bytes through Scylla, verify the SHA-256
digest, and dump how the blob was laid out across salted partitions.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import time
from typing import Optional

from cassandra.auth import PlainTextAuthProvider  # type: ignore[import-untyped]
from cassandra.cluster import Cluster             # type: ignore[import-untyped]

from salted_blob_store import DEFAULT_MAX_CONCURRENCY, SaltedBlobStore


def fmt_bytes(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024:
            return f"{n:7.2f} {unit}"
        n /= 1024
    return f"{n:7.2f} TiB"


def run_case(
    store: SaltedBlobStore,
    name: str,
    key: bytes,
    blob: bytes,
    *,
    max_salt: int,
    chunk_size: int,
    max_concurrency: int = DEFAULT_MAX_CONCURRENCY,
) -> None:
    digest_in = hashlib.sha256(blob).hexdigest()
    print(f"\n=== {name} ===")
    print(f"  key        : {key!r}")
    print(f"  size       : {fmt_bytes(len(blob))}")
    print(f"  max_salt   : {max_salt}")
    print(f"  chunk_size : {fmt_bytes(chunk_size)}")
    print(f"  sha256(in) : {digest_in}")

    t0 = time.perf_counter()
    store.write(key, blob, max_salt=max_salt, chunk_size=chunk_size,
                max_concurrency=max_concurrency)
    write_ms = (time.perf_counter() - t0) * 1000

    t0 = time.perf_counter()
    out = store.read(key, max_concurrency=max_concurrency)
    read_ms = (time.perf_counter() - t0) * 1000

    assert out is not None, "blob unexpectedly missing after write"
    h = hashlib.sha256()
    for chunk in out:
        h.update(chunk)
    digest_out = h.hexdigest()
    print(f"  sha256(out): {digest_out}")
    print(f"  write      : {write_ms:8.1f} ms")
    print(f"  read       : {read_ms:8.1f} ms")
    if digest_in != digest_out:
        raise SystemExit("FAIL: round-trip digest mismatch")
    print("  round-trip : OK")

    layout = store.describe(key, max_concurrency=max_concurrency)
    assert layout is not None
    print(
        f"  layout     : total_chunks={layout.total_chunks}, "
        f"salt_cardinality={layout.salt_cardinality}, "
        f"stored_bytes={fmt_bytes(layout.total_bytes)}"
    )
    preview = layout.partitions[:5]
    for p in preview:
        print(f"    salt={p.salt:>3}  rows={p.rows:>4}  bytes={fmt_bytes(p.bytes)}")
    if len(layout.partitions) > len(preview):
        print(f"    ... ({len(layout.partitions) - len(preview)} more salted partitions)")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--contact-points", default=os.environ.get("SCYLLA_CONTACT_POINTS", "127.0.0.1"),
        help="Comma-separated host list (default: 127.0.0.1).",
    )
    p.add_argument("--port", type=int, default=int(os.environ.get("SCYLLA_PORT", "9042")))
    p.add_argument("--username", default=os.environ.get("SCYLLA_USERNAME"))
    p.add_argument("--password", default=os.environ.get("SCYLLA_PASSWORD"))
    p.add_argument("--keyspace", default="salted_blob_demo")
    p.add_argument("--table", default="salted_blobs")
    p.add_argument("--rf", type=int, default=1, help="replication_factor for the demo keyspace")
    p.add_argument(
        "--large-mb", type=int, default=8,
        help="Size of the large-blob test case in MiB (default: 8).",
    )
    p.add_argument(
        "--max-concurrency", type=int, default=DEFAULT_MAX_CONCURRENCY,
        help="Max in-flight CQL futures per store call (0 = unlimited, default: 0).",
    )
    p.add_argument("--cleanup", action="store_true", help="Drop the keyspace after the demo.")
    return p.parse_args()


def main() -> None:
    args = parse_args()

    auth: Optional[PlainTextAuthProvider] = None
    if args.username:
        auth = PlainTextAuthProvider(username=args.username, password=args.password or "")

    cluster = Cluster(
        contact_points=[h.strip() for h in args.contact_points.split(",") if h.strip()],
        port=args.port,
        auth_provider=auth,
        protocol_version=4,
    )
    session = cluster.connect()
    try:
        store = SaltedBlobStore(session, keyspace=args.keyspace, table=args.table)
        store.create_schema(replication={"class": "SimpleStrategy", "replication_factor": args.rf})

        # Deterministic but non-trivial payloads.
        rng = lambda seed, size: hashlib.shake_128(seed).digest(size)  # noqa: E731

        # 1) Small blob: no chunking, single partition, single row.
        run_case(
            store, "small blob (no chunking)",
            key=b"small-key",
            blob=rng(b"small", 2 * 1024),  # 2 KiB
            max_salt=1,
            chunk_size=4096,
            max_concurrency=args.max_concurrency,
        )

        # 2) Medium blob: a handful of salts, several rows per partition.
        run_case(
            store, "medium blob (a few salts)",
            key=b"medium-key",
            blob=rng(b"medium", 256 * 1024),  # 256 KiB
            max_salt=8,
            chunk_size=4096,
            max_concurrency=args.max_concurrency,
        )

        # 3) Large blob: many salts, parallelism across shards.
        large_size = args.large_mb * 1024 * 1024
        run_case(
            store, f"large blob (high salting, {args.large_mb} MiB)",
            key=b"large-key",
            blob=rng(b"large", large_size),
            max_salt=100,
            chunk_size=64 * 1024,  # 64 KiB chunks
            max_concurrency=args.max_concurrency,
        )

        # Demonstrate read of a missing key.
        print("\n=== missing key ===")
        missing = store.read(b"does-not-exist", max_concurrency=args.max_concurrency)
        print(f"  read(missing) -> {missing!r}")

        # Demonstrate delete.
        print("\n=== delete medium-key ===")
        store.delete(b"medium-key", max_concurrency=args.max_concurrency)
        print(f"  read(medium-key) -> {store.read(b'medium-key', max_concurrency=args.max_concurrency)!r}")

        if args.cleanup:
            print("\nCleaning up keyspace...")
            store.drop_schema()
    finally:
        cluster.shutdown()


if __name__ == "__main__":
    main()
