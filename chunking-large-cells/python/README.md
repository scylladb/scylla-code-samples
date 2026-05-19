# Chunking large cells — Python demo

A runnable companion to the blog post **"Storing large blobs in ScyllaDB"**.
It implements the *Modified Salting* technique: large blobs are split into
fixed-size chunks distributed across `salt_cardinality` partitions per key,
so reads and writes can be parallelised across shards while the metadata
(`total_chunks`, `salt_cardinality`) carried on `(salt=0, chunk_id=0)`
prevents wasteful scans of empty partitions.

## Files

| File                   | Purpose                                                                 |
|------------------------|-------------------------------------------------------------------------|
| `salted_blob_store.py` | Library: schema management, write, read, delete, describe               |
| `demo.py`              | End-to-end demo (small / medium / large blobs, round-trip verification) |
| `benchmark.py`         | Large-blob vs small-blob throughput and latency benchmark               |
| `requirements.txt`     | Python dependencies                                                     |

## Schema

```cql
CREATE TABLE <keyspace>.salted_blobs (
    key blob,
    salt int,
    chunk_id int,
    chunk blob,
    total_chunks int,
    salt_cardinality int,
    PRIMARY KEY ((key, salt), chunk_id)
);
```

## Quick start

```bash
# 1. Bring up a single-node ScyllaDB
docker run --name scylla-blobs -d -p 9042:9042 scylladb/scylla \
    --smp 2 --memory 2G --overprovisioned 1

# 2. Install the driver
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 3. Run the demo
python demo.py --contact-points 127.0.0.1
```

The demo will:

1. create keyspace `salted_blob_demo` and table `salted_blobs`,
2. write a 2 KiB blob with `max_salt=1` (no chunking),
3. write a 256 KiB blob with `max_salt=8` (a handful of salts),
4. write an 8 MiB blob with `max_salt=100`, `chunk_size=64 KiB`
   (high parallelism — bump it with `--large-mb 30` to mirror the blog),
5. round-trip every blob and verify the SHA-256 digest,
6. dump how each blob is laid out across salted partitions,
7. show that `read()` of a missing key returns `None`,
8. delete a key and confirm it's gone.

Pass `--cleanup` to drop the keyspace at the end.  
Use `--max-concurrency N` to cap the number of in-flight CQL futures inside
each `write()` / `read()` / `delete()` call (default `0` = unlimited).

## Benchmark — large blobs vs small blobs

`benchmark.py` measures the same total byte volume written and read two ways:

| Case            | What is one "operation"                                                                       |
|-----------------|-----------------------------------------------------------------------------------------------|
| **Large blobs** | Write / read one `--large-mb` MiB blob via `SaltedBlobStore` (chunks parallelised internally) |
| **Small blobs** | One CQL `INSERT` / `SELECT` of a single `--small-kb` KiB row                                  |

The final report prints per-operation latency (min / p50 / p99 / max) and
aggregate throughput (MiB/s) side-by-side for both cases.

```bash
# Quick smoke-test: 10 × 30 MiB large blobs ≈ 300 MiB total
python benchmark.py --count 10

# Full benchmark: 1,000 × 30 MiB ≈ 30 GiB total (requires sufficient disk)
python benchmark.py --count 1000

# Tune blob sizes and concurrency
python benchmark.py --count 100 --large-mb 30 --small-kb 128 --concurrency 128

# Cap in-flight store futures for large-blob ops (sliding window inside SaltedBlobStore)
python benchmark.py --count 10 --store-concurrency 32

# Drop the keyspace when done
python benchmark.py --count 10 --cleanup
```

Key flags:

| Flag                    | Default      | Description                                                               |
|-------------------------|--------------|---------------------------------------------------------------------------|
| `--contact-points`      | `127.0.0.1`  | Comma-separated ScyllaDB host list (or `SCYLLA_CONTACT_POINTS`)           |
| `--port`                | `9042`       | CQL port (or `SCYLLA_PORT`)                                               |
| `--username`            | _(none)_     | CQL username (or `SCYLLA_USERNAME`)                                       |
| `--password`            | _(none)_     | CQL password (or `SCYLLA_PASSWORD`)                                       |
| `--keyspace`            | `blob_bench` | Keyspace to use                                                           |
| `--rf`                  | `1`          | Replication factor                                                        |
| `--count N`             | `1000`       | Number of large blobs                                                     |
| `--large-mb M`          | `30`         | Each large blob in MiB                                                    |
| `--small-kb K`          | `64`         | Each small blob in KiB                                                    |
| `--chunk-size-kb C`     | `64`         | Chunk size for salting                                                    |
| `--max-salt S`          | `100`        | Parallel shard spread for large blobs                                     |
| `--concurrency P`       | `64`         | Async window for small-blob ops (must be `>= 1`)                          |
| `--store-concurrency N` | `0`          | Max in-flight futures inside `SaltedBlobStore.write/read` (0 = unlimited) |
| `--skip-large`          | off          | Reuse already-written large blobs                                         |
| `--skip-small`          | off          | Skip the small-blob case                                                  |
| `--cleanup`             | off          | Drop keyspace on exit                                                     |

> **Disk budget**: `count × large_mb` MiB plus the equivalent small-blob
> volume. For the default `1000 × 30 MiB` run that is roughly **60 GiB**
> (both tables together with RF=1). Use `--count 10` or `--count 100` for
> smaller runs.

## Library usage

```python
from cassandra.cluster import Cluster
from salted_blob_store import SaltedBlobStore
import itertools

cluster = Cluster(["127.0.0.1"])
session = cluster.connect()

store = SaltedBlobStore(session, keyspace="my_ks")
store.create_schema(replication={"class": "SimpleStrategy", "replication_factor": 1})

# Hybrid policy: small blobs stay on a single partition,
# big blobs spread across many shards.
store.write(key=b"small", blob=b"...", max_salt=1, chunk_size=4096)
store.write(key=b"huge",  blob=big_bytes, max_salt=100, chunk_size=64 * 1024)

# max_concurrency > 0 enables a true sliding window: at most N batch / SELECT
# futures are in-flight at once; 0 (default) fires all of them concurrently.
store.write(key=b"huge2", blob=big_bytes, max_salt=100, chunk_size=64 * 1024,
            max_concurrency=32)

assert all(a == b for a, b in zip(itertools.chain.from_iterable(store.read(b"small")), b"...", strict=True))
print(store.describe(b"huge"))
```

`max_salt` and `chunk_size` are per-call arguments — the same table can hold
keys with completely different salting parameters, which is the central
flexibility the blog highlights versus classic salting.

## Notes

* **`write()` parameter checks** — invalid tuning values raise `ValueError`
  before any CQL is issued:

  | Parameter         | Constraint                          |
  |-------------------|-------------------------------------|
  | `max_salt`        | `>= 1`                              |
  | `chunk_size`      | `>= 1`                              |
  | `max_batch_bytes` | `>= chunk_size` (and `>= 1`)        |
  | `max_concurrency` | `>= 0` (`0` = unlimited in-flight)  |

  The `max_batch_bytes >= chunk_size` rule guarantees every UNLOGGED batch
  can hold at least one full chunk, so batch sizing stays predictable
  relative to the server's `batch_size_fail_threshold_in_kb`.  Default
  `max_batch_bytes` is 1 MiB (`DEFAULT_MAX_BATCH_BYTES`).
* **Empty blobs** — `write(key, b"")` stores a single sentinel row
  `(salt=0, chunk_id=0)` with `total_chunks=0`.  `read(key)` short-circuits
  on that sentinel and returns `[]` without issuing any partition SELECTs.
* Writes use `BatchType.UNLOGGED` per salted partition (one batch per salt,
  split into smaller batches once the accumulated chunk payload exceeds
  `max_batch_bytes` — default 1 MiB — so the server's
  `batch_size_fail_threshold_in_kb` is not tripped).
* Reads issue one async per-partition `SELECT` per salt and reassemble the
  chunks in `chunk_id` order; the per-key metadata is fetched once via a
  cheap point query against `(salt=0, chunk_id=0)`.
* **Metadata validation** — `_fetch_meta()` raises `RuntimeError` if the
  stored sentinel row has a negative `total_chunks` or non-positive
  `salt_cardinality`, so `read`, `delete`, and `describe` all reject corrupt
  metadata uniformly instead of silently proceeding with bad values.
* **Chunk-row integrity** — `read()` rejects rows whose `chunk_id` is out of
  range or whose payload is empty (an empty chunk row inside a non-empty
  blob signals corruption, since `write()` only stores empty rows for empty
  blobs via the `total_chunks=0` sentinel path).
* **`delete()` ordering** — chunk partitions (`salt != 0`) are removed
  first; the sentinel partition (`salt=0`, carrying `total_chunks` and
  `salt_cardinality`) is deleted last.  If a delete fails partway through,
  the sentinel row is still present so the operation can be retried.
* **Concurrency control** — `write`, `read`, `delete`, and `describe` accept
  `max_concurrency`:
  * `0` (default) — all futures are issued at once; Python awaits them in
    submission order (equivalent to the unlimited path in the C++ port).
  * `N > 0` — a `threading.Semaphore(N)` limits in-flight futures to exactly
    `N`; the driver's I/O thread releases a slot the moment any future
    completes, immediately unblocking the producer for the next one (true
    sliding window, no FIFO batch-stalling).  A drain loop acquires all `N`
    permits before returning, then re-raises the first error if any occurred.
* `cassandra-driver` works against ScyllaDB; if you prefer the Scylla fork
  swap the dependency for `scylla-driver` — the API is identical.
