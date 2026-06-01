#!/usr/bin/env python3
"""
Large-blob vs small-blob benchmark for ScyllaDB.

Compares the same total byte volume written and read in two ways:

  LARGE BLOB CASE
    --count blobs, each --large-mb MiB, stored via Modified-Salting
    (SaltedBlobStore: chunked across multiple partitions, reads/writes
    parallelised with async CQL).  One write() or read() call constitutes
    a single "operation" whose wall-clock time is measured.

  SMALL BLOB CASE
    ceil(count * large_mb / small_kb) blobs, each --small-kb KiB, stored
    as a single row per blob (one CQL INSERT or SELECT per operation).
    A sliding async window of --concurrency outstanding requests drives
    throughput.

The final report shows per-operation latency (min / p50 / p99 / max) and
aggregate throughput (MiB/s) side-by-side for both cases.

Defaults: 1,000 × 30 MiB large blobs  ≈ 29.3 GiB total
          matched by ~480,000 × 64 KiB small blobs
WARNING : 1,000 × 30 MiB requires ~30 GiB of free disk space on ScyllaDB.
          Use --count 10 (or --count 100) for a faster smoke-test.
"""
from __future__ import annotations

import argparse
import math
import os
import threading
import time
from typing import List, Optional, Tuple

from cassandra.auth import PlainTextAuthProvider  # type: ignore[import-untyped]
from cassandra.cluster import Cluster             # type: ignore[import-untyped]

from salted_blob_store import DEFAULT_MAX_CONCURRENCY, SaltedBlobStore

# ── formatting helpers ────────────────────────────────────────────────────────

RULER = "━" * 72


def fmt_bytes(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024:
            return f"{n:.2f} {unit}"
        n /= 1024
    return f"{n:.2f} PiB"


def fmt_ms(ms: float) -> str:
    if ms < 1_000:
        return f"{ms:.1f} ms"
    return f"{ms / 1_000:.2f} s"


def fmt_s(s: float) -> str:
    if s < 60:
        return f"{s:.1f} s"
    m, sec = divmod(s, 60)
    return f"{int(m)}m {sec:.0f}s"


def pct(data: List[float], p: float) -> float:
    """
    Return the p-th percentile of data (linear interpolation).
    """
    if not data:
        return 0.0
    s = sorted(data)
    idx = p / 100.0 * (len(s) - 1)
    lo, hi = int(idx), min(int(idx) + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def _progress(done: int, total: int, t_start: float) -> None:
    elapsed = time.perf_counter() - t_start
    frac = done / total if total else 0
    eta = (elapsed / frac - elapsed) if frac > 0 else 0
    width = 30
    filled = int(width * frac)
    bar = "█" * filled + "░" * (width - filled)
    print(
        f"\r  [{bar}] {done:>{len(str(total))}}/{total}"
        f"  {elapsed:.0f}s elapsed  ~{eta:.0f}s left   ",
        end="",
        flush=True,
    )


# ── large blob benchmark ──────────────────────────────────────────────────────


def bench_large(
    store: SaltedBlobStore,
    count: int,
    blob_size: int,
    max_salt: int,
    chunk_size: int,
    payload: bytes,
    store_concurrency: int = DEFAULT_MAX_CONCURRENCY,
) -> Tuple[List[float], List[float], float, float]:
    """
    Write then read *count* large blobs.
    Returns (write_latencies_s, read_latencies_s, write_wall_s, read_wall_s).

    ``store_concurrency`` is forwarded to ``SaltedBlobStore.write()`` and
    ``read()`` as ``max_concurrency`` (0 = unlimited, >0 = sliding window).
    """
    keys = [f"bench-large-{i:07d}".encode() for i in range(count)]

    print(f"\n{RULER}")
    print(f"  LARGE BLOB WRITE  —  {count:,} × {fmt_bytes(blob_size)}")
    print(RULER)
    write_lats: List[float] = []
    t_wall = time.perf_counter()
    report_step = max(1, count // 50)
    for i, key in enumerate(keys):
        t0 = time.perf_counter()
        store.write(key, payload, max_salt=max_salt, chunk_size=chunk_size,
                    max_concurrency=store_concurrency)
        write_lats.append(time.perf_counter() - t0)
        if (i + 1) % report_step == 0 or i + 1 == count:
            _progress(i + 1, count, t_wall)
    total_write_s = time.perf_counter() - t_wall
    print(f"\n  done in {fmt_s(total_write_s)}  "
          f"({fmt_bytes(count * blob_size / total_write_s)}/s)")

    print(f"\n{RULER}")
    print(f"  LARGE BLOB READ   —  {count:,} × {fmt_bytes(blob_size)}")
    print(RULER)
    read_lats: List[float] = []
    t_wall = time.perf_counter()
    for i, key in enumerate(keys):
        t0 = time.perf_counter()
        data = store.read(key, max_concurrency=store_concurrency)
        read_lats.append(time.perf_counter() - t0)
        assert data is not None, f"missing blob for key {key!r}"
        if (i + 1) % report_step == 0 or i + 1 == count:
            _progress(i + 1, count, t_wall)
    total_read_s = time.perf_counter() - t_wall
    print(f"\n  done in {fmt_s(total_read_s)}  "
          f"({fmt_bytes(count * blob_size / total_read_s)}/s)")

    return write_lats, read_lats, total_write_s, total_read_s


# ── small blob benchmark ──────────────────────────────────────────────────────


def _setup_small_table(session, ks: str) -> None:
    session.execute(
        f"CREATE TABLE IF NOT EXISTS {ks}.small_blobs ("
        f"  key blob PRIMARY KEY, data blob)"
    )


def _run_async_window(session, stmt, params_list: list, concurrency: int) -> List[float]:
    """
    Issue async CQL requests with a true sliding window of *concurrency*
    in-flight requests: the moment any op completes a new one is issued,
    keeping the pipeline always full.

    Uses a threading.Semaphore for backpressure (acquire before issue,
    release in the per-future callback) so the producer never waits for
    an entire batch to drain.

    Returns per-operation latencies (wall-clock from issue to result).
    """
    n = len(params_list)
    lats: List[float] = [0.0] * n
    errors: List[Optional[Exception]] = [None]  # first error, shared via list
    lock = threading.Lock()

    slots = threading.Semaphore(concurrency)
    t_wall = time.perf_counter()
    report_step = max(1, n // 50)
    completed = [0]  # mutable counter read by progress reports

    def on_done(idx: int, t0: float, result, exc) -> None:  # noqa: ANN001
        lats[idx] = time.perf_counter() - t0
        if exc is not None:
            with lock:
                if errors[0] is None:
                    errors[0] = exc
        with lock:
            completed[0] += 1
        slots.release()

    last_reported = 0
    for i, params in enumerate(params_list):
        slots.acquire()
        if errors[0] is not None:
            slots.release()   # unused permit — restore invariant
            break
        t0 = time.perf_counter()
        fut = session.execute_async(stmt, params)
        fut.add_callbacks(
            callback=lambda res, idx=i, t0=t0: on_done(idx, t0, res, None),
            errback=lambda exc, idx=i, t0=t0: on_done(idx, t0, None, exc),
        )
        with lock:
            done_now = completed[0]
        if done_now >= last_reported + report_step:
            _progress(done_now, n, t_wall)
            last_reported = done_now

    # Drain: wait for all outstanding ops to release their permits.
    for _ in range(concurrency):
        slots.acquire()

    _progress(completed[0], n, t_wall)

    if errors[0] is not None:
        raise RuntimeError(f"async op failed: {errors[0]}") from errors[0]

    return lats


def bench_small(
    session,
    ks: str,
    total_bytes: int,
    small_size: int,
    payload: bytes,
    concurrency: int,
) -> Tuple[List[float], List[float], float, float]:
    """
    Write then read small blobs totalling *total_bytes*.
    Each operation is a single CQL INSERT or SELECT.
    Returns (write_latencies_s, read_latencies_s, write_wall_s, read_wall_s).
    """
    if concurrency < 1:
        raise ValueError("concurrency must be >= 1")
    n_ops = math.ceil(total_bytes / small_size)
    keys = [f"bench-small-{i:010d}".encode() for i in range(n_ops)]

    stmt_w = session.prepare(
        f"INSERT INTO {ks}.small_blobs (key, data) VALUES (?, ?)"
    )
    stmt_r = session.prepare(
        f"SELECT data FROM {ks}.small_blobs WHERE key = ?"
    )

    print(f"\n{RULER}")
    print(
        f"  SMALL BLOB WRITE  —  {n_ops:,} × {fmt_bytes(small_size)}"
        f"  (concurrency={concurrency})"
    )
    print(RULER)
    t_wall = time.perf_counter()
    write_lats = _run_async_window(
        session, stmt_w, [(k, payload) for k in keys], concurrency
    )
    total_write_s = time.perf_counter() - t_wall
    print(f"\n  done in {fmt_s(total_write_s)}  "
          f"({fmt_bytes(total_bytes / total_write_s)}/s)")

    print(f"\n{RULER}")
    print(
        f"  SMALL BLOB READ   —  {n_ops:,} × {fmt_bytes(small_size)}"
        f"  (concurrency={concurrency})"
    )
    print(RULER)
    t_wall = time.perf_counter()
    read_lats = _run_async_window(
        session, stmt_r, [(k,) for k in keys], concurrency
    )
    total_read_s = time.perf_counter() - t_wall
    print(f"\n  done in {fmt_s(total_read_s)}  "
          f"({fmt_bytes(total_bytes / total_read_s)}/s)")

    return write_lats, read_lats, total_write_s, total_read_s


# ── summary report ────────────────────────────────────────────────────────────


def report(
    large_write: List[float],
    large_read: List[float],
    large_blob_size: int,
    large_count: int,
    large_write_wall_s: float,
    large_read_wall_s: float,
    small_write: List[float],
    small_read: List[float],
    small_blob_size: int,
    small_write_wall_s: float,
    small_read_wall_s: float,
) -> None:
    total_bytes = large_count * large_blob_size
    small_count = len(small_write)

    lw_ms = [x * 1_000 for x in large_write]
    lr_ms = [x * 1_000 for x in large_read]
    sw_ms = [x * 1_000 for x in small_write]
    sr_ms = [x * 1_000 for x in small_read]

    def throughput(wall_s: float, nbytes: int) -> str:
        if wall_s <= 0:
            return "—"
        return f"{nbytes / wall_s / (1024 ** 2):.1f} MiB/s"

    lw_tp = throughput(large_write_wall_s, total_bytes)
    lr_tp = throughput(large_read_wall_s, total_bytes)
    sw_tp = throughput(small_write_wall_s, total_bytes)
    sr_tp = throughput(small_read_wall_s, total_bytes)

    total_lw_s = large_write_wall_s
    total_lr_s = large_read_wall_s
    total_sw_s = small_write_wall_s
    total_sr_s = small_read_wall_s

    # Column widths
    C = 16

    def row(label: str, lw: str, lr: str, sw: str, sr: str) -> None:
        print(
            f"  {label:<32}"
            f"  {lw:>{C}}"
            f"  {lr:>{C}}"
            f"  {sw:>{C}}"
            f"  {sr:>{C}}"
        )

    def lat_row(label: str, p: Optional[float]) -> None:
        if p is None:
            lw = fmt_ms(min(lw_ms))
            lr = fmt_ms(min(lr_ms))
            sw = fmt_ms(min(sw_ms))
            sr = fmt_ms(min(sr_ms))
        else:
            lw = fmt_ms(pct(lw_ms, p))
            lr = fmt_ms(pct(lr_ms, p))
            sw = fmt_ms(pct(sw_ms, p))
            sr = fmt_ms(pct(sr_ms, p))
        row(label, lw, lr, sw, sr)

    print(f"\n{RULER}")
    print("  BENCHMARK RESULTS")
    print(RULER)
    print(
        f"  Total payload   : {fmt_bytes(total_bytes)}"
        f"  ({large_count:,} × {fmt_bytes(large_blob_size)} large"
        f"  |  {small_count:,} × {fmt_bytes(small_blob_size)} small)"
    )
    print()
    print(
        f"  {'':32}"
        f"  {'── LARGE BLOB ──':>{C}}"
        f"  {'':>{C}}"
        f"  {'── SMALL BLOB ──':>{C}}"
        f"  {'':>{C}}"
    )
    row("", "WRITE", "READ", "WRITE", "READ")
    print(f"  {'─'*32}  {'─'*C}  {'─'*C}  {'─'*C}  {'─'*C}")
    row("Throughput", lw_tp, lr_tp, sw_tp, sr_tp)
    print()
    row("Total time", fmt_s(total_lw_s), fmt_s(total_lr_s),
        fmt_s(total_sw_s), fmt_s(total_sr_s))
    row("Op count",
        f"{large_count:,}", f"{large_count:,}",
        f"{small_count:,}", f"{small_count:,}")
    print()
    print(
        f"  Per-op latency"
        f"  [large = one {fmt_bytes(large_blob_size)} blob;"
        f" small = one {fmt_bytes(small_blob_size)} CQL op]"
    )
    print(f"  {'─'*32}  {'─'*C}  {'─'*C}  {'─'*C}  {'─'*C}")
    lat_row("  min", None)
    lat_row("  p50", 50)
    lat_row("  p99", 99)
    row("  max",
        fmt_ms(max(lw_ms)), fmt_ms(max(lr_ms)),
        fmt_ms(max(sw_ms)), fmt_ms(max(sr_ms)))
    print(RULER)


# ── CLI ───────────────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--contact-points",
        default=os.environ.get("SCYLLA_CONTACT_POINTS", "127.0.0.1"),
        help="Comma-separated ScyllaDB host list (default: 127.0.0.1).",
    )
    p.add_argument("--port", type=int, default=int(os.environ.get("SCYLLA_PORT", "9042")))
    p.add_argument("--username", default=os.environ.get("SCYLLA_USERNAME"))
    p.add_argument("--password", default=os.environ.get("SCYLLA_PASSWORD"))
    p.add_argument("--keyspace", default="blob_bench")
    p.add_argument("--rf", type=int, default=1, help="Replication factor (default: 1).")
    p.add_argument(
        "--count", type=int, default=1000,
        help="Number of large blobs to write/read (default: 1000).",
    )
    p.add_argument(
        "--large-mb", type=int, default=30,
        help="Size of each large blob in MiB (default: 30).",
    )
    p.add_argument(
        "--small-kb", type=int, default=64,
        help="Size of each small blob in KiB (default: 64).",
    )
    p.add_argument(
        "--chunk-size-kb", type=int, default=64,
        help="Chunk size for large-blob salting in KiB (default: 64).",
    )
    p.add_argument(
        "--max-salt", type=int, default=100,
        help="max_salt (parallelism) for large blobs (default: 100).",
    )
    p.add_argument(
        "--concurrency", type=int, default=64,
        help="Async window size for small-blob ops (default: 64).",
    )
    p.add_argument(
        "--store-concurrency", type=int, default=DEFAULT_MAX_CONCURRENCY,
        help="Max in-flight CQL futures inside SaltedBlobStore.write/read "
             "(0 = unlimited, default: 0).",
    )
    p.add_argument(
        "--skip-large", action="store_true",
        help="Skip the large-blob benchmark (use previously written data).",
    )
    p.add_argument(
        "--skip-small", action="store_true",
        help="Skip the small-blob benchmark.",
    )
    p.add_argument(
        "--cleanup", action="store_true",
        help="DROP the keyspace when the benchmark finishes.",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()

    blob_size   = args.large_mb * 1024 * 1024          # noqa: E221
    small_size  = args.small_kb * 1024                 # noqa: E221
    total_bytes = args.count * blob_size               # noqa: E221
    n_small     = math.ceil(total_bytes / small_size)  # noqa: E221

    print(RULER)
    print("  ScyllaDB  ·  Large-vs-Small Blob Benchmark")
    print(RULER)
    print(f"  Large blobs  : {args.count:,} × {args.large_mb} MiB"
          f"  =  {fmt_bytes(total_bytes)} total")
    print(f"  Small blobs  : {n_small:,} × {args.small_kb} KiB"
          f"  ≈  {fmt_bytes(n_small * small_size)} total")
    print(f"  Chunk size   : {args.chunk_size_kb} KiB"
          f"   max_salt={args.max_salt}"
          f"   concurrency={args.concurrency}"
          f"   store_concurrency={args.store_concurrency}")
    print(f"  ScyllaDB     : {args.contact_points}:{args.port}"
          f"   keyspace={args.keyspace}   rf={args.rf}")
    print(RULER)

    auth: Optional[PlainTextAuthProvider] = None
    if args.username:
        auth = PlainTextAuthProvider(
            username=args.username, password=args.password or ""
        )

    cluster = Cluster(
        contact_points=[h.strip() for h in args.contact_points.split(",") if h.strip()],
        port=args.port,
        auth_provider=auth,
        protocol_version=4,
    )
    session = cluster.connect()

    ks = args.keyspace
    session.execute(
        f"CREATE KEYSPACE IF NOT EXISTS {ks} WITH replication = "
        f"{{'class': 'SimpleStrategy', 'replication_factor': {args.rf}}}"
    )

    # One fixed payload reused for all writes; content is irrelevant for
    # an I/O benchmark and avoids generating gigabytes of random data.
    print("\n  Generating payload buffers...", end=" ", flush=True)
    large_payload = os.urandom(blob_size)
    small_payload = large_payload[:small_size]
    print("done.")

    large_write_lats: List[float] = []
    large_read_lats:  List[float] = []
    large_write_wall_s: float = 0.0
    large_read_wall_s:  float = 0.0
    small_write_lats: List[float] = []
    small_read_lats:  List[float] = []
    small_write_wall_s: float = 0.0
    small_read_wall_s:  float = 0.0

    if not args.skip_large:
        store = SaltedBlobStore(session, keyspace=ks, table="salted_blobs")
        store.create_schema(
            replication={"class": "SimpleStrategy", "replication_factor": args.rf}
        )
        large_write_lats, large_read_lats, large_write_wall_s, large_read_wall_s = bench_large(
            store,
            count=args.count,
            blob_size=blob_size,
            max_salt=args.max_salt,
            chunk_size=args.chunk_size_kb * 1024,
            payload=large_payload,
            store_concurrency=args.store_concurrency,
        )

    if not args.skip_small:
        _setup_small_table(session, ks)
        small_write_lats, small_read_lats, small_write_wall_s, small_read_wall_s = bench_small(
            session,
            ks=ks,
            total_bytes=total_bytes,
            small_size=small_size,
            payload=small_payload,
            concurrency=args.concurrency,
        )

    if large_write_lats and small_write_lats:
        report(
            large_write_lats, large_read_lats, blob_size, args.count,
            large_write_wall_s, large_read_wall_s,
            small_write_lats, small_read_lats, small_size,
            small_write_wall_s, small_read_wall_s,
        )
    else:
        print("\n(Skipped one or both benchmark cases — no comparison printed.)")

    if args.cleanup:
        print(f"\n  Dropping keyspace {ks} ...", end=" ", flush=True)
        session.execute(f"DROP KEYSPACE IF EXISTS {ks}")
        print("done.")

    cluster.shutdown()


if __name__ == "__main__":
    main()
