# Chunking large cells — C++ demo

C++23 port of [`../python`](../python/) using the
[ScyllaDB C++ Driver (cpp-rs-driver)](https://cpp-rs-driver.docs.scylladb.com/stable/)
(`libscylla-cpp-driver`). The DataStax driver (`libcassandra`) is also
supported as a fallback — both expose the same `cassandra.h` API.

## Files

| File                           | Purpose                                                                                                                         |
|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| `salted_blob_store.h` / `.cpp` | Library: schema management, write, read, erase, describe                                                                        |
| `demo.cpp`                     | End-to-end demo (small / medium / large blobs, round-trip verification)                                                         |
| `benchmark.cpp`                | Large-blob vs small-blob throughput and latency benchmark                                                                       |
| `CMakeLists.txt`               | Build configuration (`pkg-config` used when available; falls back to `find_library` if absent or if no pkg-config module found) |

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

## Prerequisites

The [ScyllaDB C++ Driver (cpp-rs-driver)](https://cpp-rs-driver.docs.scylladb.com/stable/),
CMake 3.16+, and a C++23-capable compiler:

* **Ubuntu / Debian** — download the runtime and dev `.deb` packages from the
  [releases page](https://github.com/scylladb/cpp-rs-driver/releases) and install:
  ```bash
  apt install ./scylla-cpp-driver_*.deb ./scylla-cpp-driver-dev_*.deb
  apt install cmake g++-14 pkg-config
  ```
  Ubuntu 24.04's default `g++` (GCC 13) lacks `<print>`; GCC 14 is required
  for full C++23 support. See the [Build](#build) section for how to point CMake
  at `g++-14`.
* **RHEL / Rocky / Fedora** — download the matching `.rpm` packages from the
  [releases page](https://github.com/scylladb/cpp-rs-driver/releases) and install:
  ```bash
  dnf install scylla-cpp-driver-*.rpm scylla-cpp-driver-devel-*.rpm
  dnf install cmake gcc-c++ pkgconf-pkg-config
  ```
* **macOS (Homebrew)** — no Scylla driver formula exists yet; the DataStax
  driver is used as a fallback:
  ```bash
  brew install cmake pkg-config cassandra-cpp-driver
  ```
  CMake finds the Homebrew-installed headers and library automatically via the
  `/opt/homebrew/include` / `/opt/homebrew/lib` search paths.
* **Build from source** — <https://cpp-rs-driver.docs.scylladb.com/stable/topics/building.html>.
* **Fallback** — the DataStax `cassandra-cpp-driver-dev` / `libcassandra-dev`
  package also works on Linux; CMake detects it automatically if the Scylla
  package is absent.

> **Note:** both the runtime package (`scylla-cpp-driver`) and the dev package
> (`scylla-cpp-driver-dev` / `-devel`) are required. The dev package provides
> `cassandra.h` and the `.so` symlink; the runtime package provides the versioned
> `.so` that the linker and dynamic loader need.

## Build

```bash
cd chunking-large-cells/cpp
cmake -S . -B build
cmake --build build -j
```

On **Ubuntu 24.04**, point CMake at GCC 14 explicitly (the default `g++` is
GCC 13, which lacks C++23's `<print>`):

```bash
CC=gcc-14 CXX=g++-14 cmake -S . -B build
cmake --build build -j
```

CMake uses `pkg-config` when available to locate the driver (searching
`scylla-cpp-driver` first, then `cassandra`). If `pkg-config` is absent or
neither module is found, it falls back to `find_path`/`find_library` across the
standard system and Homebrew prefixes. On RPM-based distros the `.pc` file is in
`/usr/lib64/pkgconfig`; CMake prepends that path to `PKG_CONFIG_PATH`
automatically.

The build embeds an rpath into the binary so `libscylla-cpp-driver.so` is found
at runtime without needing `LD_LIBRARY_PATH` or changes to `/etc/ld.so.conf`.

## Run

Spin up a single-node ScyllaDB and run the demo:

```bash
docker run --name scylla-blobs -d -p 9042:9042 scylladb/scylla \
    --smp 2 --memory 2G --overprovisioned 1

./build/demo --contact-points 127.0.0.1 --large-mb 30

# Cap in-flight CQL futures to a sliding window of 32 (default: 0 = unlimited)
./build/demo --contact-points 127.0.0.1 --large-mb 30 --max-concurrency 32
```

The demo will:

1. create keyspace `salted_blob_demo` and table `salted_blobs`,
2. write a 2 KiB blob with `max_salt=1` (no chunking),
3. write a 256 KiB blob with `max_salt=8` (a handful of salts),
4. write a `--large-mb`-sized blob (default 8 MiB) with `max_salt=100`, `chunk_size=64 KiB`,
5. round-trip every blob and verify with an FNV-1a fingerprint and `std::ranges::equal` over the flattened chunk vector,
6. dump how each blob is laid out across salted partitions,
7. show that `read()` of a missing key returns `std::nullopt`,
8. delete a key and confirm it's gone.

Pass `--cleanup` to drop the keyspace at the end.  
Use `--max-concurrency N` to cap the number of in-flight CQL futures inside
each `write()` / `read()` / `erase()` call (default `0` = unlimited — all
batch / SELECT futures are issued at once and awaited together).  
Connection settings can also be provided via environment variables:
`SCYLLA_CONTACT_POINTS`, `SCYLLA_PORT`, `SCYLLA_USERNAME`, `SCYLLA_PASSWORD`.

## Benchmark — large blobs vs small blobs

`benchmark` mirrors [`../python/benchmark.py`](../python/benchmark.py) and
measures the same total byte volume written and read two ways:

| Case            | What is one "operation"                                                                       |
|-----------------|-----------------------------------------------------------------------------------------------|
| **Large blobs** | Write / read one `--large-mb` MiB blob via `SaltedBlobStore` (chunks parallelised internally) |
| **Small blobs** | One CQL `INSERT` / `SELECT` of a single `--small-kb` KiB row                                  |

The final report prints per-operation latency (min / p50 / p99 / max) and
aggregate throughput (MiB/s) side-by-side for both cases.

```bash
# Quick smoke-test: 10 × 30 MiB large blobs ≈ 300 MiB total
./build/benchmark --count 10

# Full benchmark: 1,000 × 30 MiB ≈ 30 GiB total (requires sufficient disk)
./build/benchmark --count 1000

# Tune sizes, concurrency, and the store sliding window
./build/benchmark --count 100 --large-mb 30 --small-kb 128 \
    --concurrency 128 --max-concurrency 32

# Drop the keyspace when done
./build/benchmark --count 10 --cleanup
```

Key flags:

| Flag                  | Default      | Description                                                               |
|-----------------------|--------------|---------------------------------------------------------------------------|
| `--contact-points`    | `127.0.0.1`  | Comma-separated ScyllaDB host list (or `SCYLLA_CONTACT_POINTS`)           |
| `--port`              | `9042`       | CQL port (or `SCYLLA_PORT`)                                               |
| `--username`          | _(none)_     | CQL username (or `SCYLLA_USERNAME`)                                       |
| `--password`          | _(none)_     | CQL password (or `SCYLLA_PASSWORD`)                                       |
| `--keyspace`          | `blob_bench` | Keyspace to use                                                           |
| `--rf N`              | `1`          | Replication factor                                                        |
| `--count N`           | `1000`       | Number of large blobs                                                     |
| `--large-mb M`        | `30`         | Each large blob in MiB                                                    |
| `--small-kb K`        | `64`         | Each small blob in KiB                                                    |
| `--chunk-size-kb C`   | `64`         | Chunk size for large-blob salting                                         |
| `--max-salt S`        | `100`        | Parallel shard spread for large blobs                                     |
| `--concurrency P`     | `64`         | Async sliding-window size for small-blob ops (must be `>= 1`)             |
| `--max-concurrency N` | `0`          | Max in-flight futures inside `SaltedBlobStore.write/read` (0 = unlimited) |
| `--skip-large`        | off          | Reuse already-written large blobs                                         |
| `--skip-small`        | off          | Skip the small-blob case                                                  |
| `--cleanup`           | off          | Drop keyspace on exit                                                     |

> **Disk budget**: `count × large_mb` MiB plus the equivalent small-blob
> volume. For the default `1000 × 30 MiB` run that is roughly **60 GiB**
> (both tables together with RF=1). Use `--count 10` or `--count 100` for
> smaller runs.

## Library usage

```cpp
#include "salted_blob_store.h"
#include <cassandra.h>
#include <algorithm>  // std::ranges::equal
#include <ranges>     // std::views::join

CassCluster* cluster = cass_cluster_new();
cass_cluster_set_contact_points(cluster, "127.0.0.1");
cass_cluster_set_protocol_version(cluster, 4);        // required for shard-aware routing
cass_cluster_set_token_aware_routing(cluster, cass_true);
CassSession* session = cass_session_new();
cass_future_wait(cass_session_connect(session, cluster));

scs::SaltedBlobStore store(session, "my_ks");
store.create_schema(/*replication_factor=*/1);

// Hybrid policy: small blobs stay on a single partition,
// big blobs spread across many shards.
store.write(small_key, small_blob, /*max_salt=*/1,   /*chunk_size=*/4096);
store.write(huge_key,  huge_blob,  /*max_salt=*/100, /*chunk_size=*/64 * 1024);

// max_concurrency > 0 enables a true sliding window via std::counting_semaphore:
// the callback releases a slot the moment the future completes, immediately
// unblocking the producer.  0 (default) fires all futures at once.
store.write(huge_key2, huge_blob, /*max_salt=*/100, /*chunk_size=*/64 * 1024,
            scs::kDefaultMaxBatchBytes, /*max_concurrency=*/32);

// read() returns the per-chunk vectors; join them to get a flat byte sequence.
auto chunks = store.read(small_key);             // unlimited concurrency
auto chunks2 = store.read(huge_key, /*max_concurrency=*/32);  // sliding window
if (chunks)
    auto flat = *chunks | std::views::join;  // lazy flat view over all chunk bytes

auto info = store.describe(huge_key);  // std::optional<scs::BlobLayout>
```

`max_salt` and `chunk_size` are per-call — the same table can hold keys with
completely different salting parameters.

## Notes

* **`write()` parameter checks** — invalid tuning values throw
  `std::invalid_argument` before any CQL is issued:

  | Parameter         | Constraint                          |
  |-------------------|-------------------------------------|
  | `max_salt`        | `>= 1`                              |
  | `chunk_size`      | `>= 1`                              |
  | `max_batch_bytes` | `>= chunk_size` (and `>= 1`)        |
  | `max_concurrency` | `>= 0` (`0` = unlimited in-flight)  |

  The `max_batch_bytes >= chunk_size` rule guarantees every UNLOGGED batch
  can hold at least one full chunk, so batch sizing stays predictable
  relative to the server's `batch_size_fail_threshold_in_kb`.  Default
  `max_batch_bytes` is 1 MiB (`scs::kDefaultMaxBatchBytes`).
* **Empty blobs** — `write(key, {})` stores a single sentinel row
  `(salt=0, chunk_id=0)` with `total_chunks=0`.  `read(key)` short-circuits
  on that sentinel and returns an empty `std::vector<Bytes>` without issuing
  any partition SELECTs.
* Writes use `CASS_BATCH_TYPE_UNLOGGED` per salted partition (one batch per
  salt, split once the accumulated chunk payload exceeds `max_batch_bytes`
  — default 1 MiB — to stay under the server's
  `batch_size_fail_threshold_in_kb`).
* Reads issue one async per-partition `SELECT` per salt and return the per-chunk
  byte vectors without an extra copy; `chunk_id` order is reconstructed from the
  row metadata. Metadata is fetched once via a cheap point query on
  `(salt=0, chunk_id=0)`.
* **Metadata validation** — the `KeyMeta` constructor (invoked from
  `fetch_meta`) throws `std::runtime_error` if the stored sentinel row has a
  negative `total_chunks` or non-positive `salt_cardinality`, so `read`,
  `erase`, and `describe` all reject corrupt metadata uniformly instead of
  silently proceeding with bad values.
* **Chunk-row integrity** — `read()` rejects rows whose `chunk_id` is out of
  range or whose payload is empty (an empty chunk row inside a non-empty
  blob signals corruption, since `write()` only stores empty rows for empty
  blobs via the `total_chunks=0` sentinel path).
* **`erase()` ordering** — chunk partitions (`salt != 0`) are removed first;
  the sentinel partition (`salt=0`, carrying `total_chunks` and
  `salt_cardinality`) is deleted last.  If an erase fails partway through,
  the sentinel row is still present so the operation can be retried.
* **No move semantics** — `SaltedBlobStore` is non-copyable and
  non-movable (move ctor/assign are explicitly `= delete`) because the
  cached `CassPrepared*` handles are owning raw pointers.  Wrap instances
  in `std::unique_ptr<SaltedBlobStore>` or `std::optional<SaltedBlobStore>`
  if you need them to live inside a container.
* **Concurrency control** — `write`, `read`, `erase`, and `describe` accept
  `max_concurrency` (last parameter where applicable):
  * `0` (default) — all batch / SELECT futures are collected first, then
    awaited together (unlimited parallelism).
  * `N > 0` — a `std::counting_semaphore<>(N)` limits in-flight futures to
    exactly `N`.  Completion callbacks run on driver I/O threads; each one
    records any error via an atomic `CallbackErr` accumulator and immediately
    calls `slots.release()`, unblocking the producer for the next future
    without any FIFO stalling.  A drain loop reacquires all `N` permits after
    the issue loop before throwing on the first recorded error.
* All driver handles (`CassFuture`, `CassResult`, `CassIterator`,
  `CassStatement`, `CassBatch`) are owned by `CassUnique<T, Free>` — a
  `std::unique_ptr` alias using a single stateless `CassDeleter<auto Free>`
  template (C++20 auto NTTP). The deleter is empty, so each handle is
  pointer-sized with no function-pointer storage overhead, and no manual
  `cass_*_free` calls are needed in the hot paths.
