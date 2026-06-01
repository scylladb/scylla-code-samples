#include "salted_blob_store.h"

#include <algorithm>
#include <atomic>
#include <format>
#include <functional>
#include <memory>
#include <mutex>
#include <ranges>
#include <semaphore>
#include <stdexcept>
#include <string>
#include <utility>

namespace scs {

namespace {

// ---------------------------------------------------------------------------
// RAII wrappers for driver objects
//
// A single stateless deleter parameterised on the C-linkage free function
// (C++20 auto NTTP) replaces five near-identical typedefs and wrap() helpers.
// Because the deleter is empty, the resulting CassUnique<T,Free> has the same
// size as a raw pointer (no extra storage for a function-pointer deleter).
// ---------------------------------------------------------------------------

template <auto Free>
struct CassDeleter {
    template <typename T> void operator()(T* p) const noexcept { Free(p); }
};

template <typename T, auto Free>
using CassUnique = std::unique_ptr<T, CassDeleter<Free>>;

using FuturePtr    = CassUnique<CassFuture,       cass_future_free>;
using ResultPtr    = CassUnique<const CassResult, cass_result_free>;
using IteratorPtr  = CassUnique<CassIterator,     cass_iterator_free>;
using StatementPtr = CassUnique<CassStatement,    cass_statement_free>;
using BatchPtr     = CassUnique<CassBatch,        cass_batch_free>;

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/// Extracts the driver error message from @p f and throws std::runtime_error.
/// @p where is prepended to the message to identify the call site.
/// Declared [[noreturn]] so the compiler knows callers need not handle a
/// normal return path.
[[noreturn]] void throw_future_error(CassFuture* f, const std::string& where) {
    const char* msg     = nullptr;
    std::size_t msg_len = 0;
    cass_future_error_message(f, &msg, &msg_len);
    throw std::runtime_error(where + ": " + std::string(msg, msg_len));
}

/// Checks @p f for a driver error without waiting.  If the future already
/// has an error code set, delegates to throw_future_error.  Call this only
/// after the future is known to be complete (i.e., after cass_future_wait).
void check(CassFuture* f, const std::string& where) {
    if (cass_future_error_code(f) != CASS_OK) [[unlikely]]
        throw_future_error(f, where);
}

/// Blocks until @p f completes, then checks its error code via check().
/// This is the synchronous "fire and wait" pattern used for DDL and
/// single-statement reads.
void wait_check(CassFuture* f, const std::string& where) {
    cass_future_wait(f);
    check(f, where);
}

// ---------------------------------------------------------------------------
// Driver utilities
// ---------------------------------------------------------------------------

/// Prepares a single CQL statement on @p session and returns the resulting
/// CassPrepared handle (caller owns it).  Blocks until the PREPARE round-trip
/// completes.
/// @throws std::runtime_error if the PREPARE fails.
const CassPrepared* prepare_one(CassSession* session, const std::string& cql) {
    FuturePtr fut{cass_session_prepare(session, cql.c_str())};
    wait_check(fut.get(), "PREPARE " + cql);
    return cass_future_get_prepared(fut.get());
}

/// Reads a CQL int column value and returns it as cass_int32_t.
/// If the value is null or of the wrong type, the driver leaves @c out at 0.
cass_int32_t get_int32(const CassValue* v) {
    cass_int32_t out = 0;
    cass_value_get_int32(v, &out);
    return out;
}

/// Binds a byte-array value to parameter @p idx of @p stmt.
///
/// The CQL driver's bind function requires a non-null pointer even for
/// zero-length blobs, so a stable dummy byte is provided in that case.
/// The data is copied by the driver, so the span need not outlive the call.
void bind_blob(CassStatement* stmt, std::size_t idx,
               std::span<const std::uint8_t> data) {
    static constexpr std::uint8_t empty = 0;
    cass_statement_bind_bytes(stmt, idx,
                              data.empty() ? &empty : data.data(),
                              data.size());
}

// ---------------------------------------------------------------------------
// Sliding-window callback infrastructure
//
// When max_concurrency > 0, write / read / erase keep exactly that many CQL
// futures in-flight at once.  The producer acquires a semaphore permit before
// issuing each future; the completion callback releases the permit.  This lets
// any completing future unblock the producer immediately, regardless of
// submission order, giving a true sliding window.
// ---------------------------------------------------------------------------

/// Shared error accumulator written by callbacks, read by the producer after
/// the drain phase.  The first error message is preserved; all subsequent
/// errors only increment the count.
struct CallbackErr {
    std::atomic<int> count{0};
    std::mutex       mu;
    std::string      first;

    void record(std::string_view msg) noexcept {
        std::lock_guard lk{mu};
        if (first.empty()) first.assign(msg);
        count.fetch_add(1, std::memory_order_relaxed);
    }
    bool any() const noexcept { return count.load(std::memory_order_acquire) > 0; }
    std::string take() { std::lock_guard lk{mu}; return std::exchange(first, {}); }
};

struct KeyMeta {
    cass_int32_t total_chunks;
    cass_int32_t salt_cardinality;

    KeyMeta(cass_int32_t total_chunks_, cass_int32_t salt_cardinality_)
        : total_chunks(total_chunks_), salt_cardinality(salt_cardinality_)
    {
        if (total_chunks < 0 || salt_cardinality <= 0)
            throw std::runtime_error(
                std::format("invalid metadata: total_chunks={}, salt_cardinality={}", total_chunks, salt_cardinality));
    }
};

using FutureTask = std::function<FuturePtr()>;
using ResultHandler = std::function<void(const CassResult*)>;
using PartitionHandler = std::function<void(int salt, const CassResult*)>;

struct AsyncTask {
    FutureTask      submit;
    ResultHandler   handle;  ///< Empty for void futures (write / erase).
};

struct AsyncCtx {
    ResultHandler               handle;
    std::counting_semaphore<>*  slots;
    CallbackErr*                err;
};

/// Completion callback for async tasks (write, erase, partition SELECT).
/// Invoked on a driver I/O thread; must be noexcept.
void on_async_done(CassFuture* fut, void* data) noexcept {
    auto* ctx = static_cast<AsyncCtx*>(data);
    if (cass_future_error_code(fut) != CASS_OK) [[unlikely]] {
        const char* msg = nullptr; std::size_t mlen = 0;
        cass_future_error_message(fut, &msg, &mlen);
        ctx->err->record({msg, mlen});
    } else if (ctx->handle) {
        ResultPtr res{cass_future_get_result(fut)};
        try {
            ctx->handle(res.get());
        } catch (const std::exception& e) {
            ctx->err->record(e.what());
        } catch (...) {
            ctx->err->record("unknown exception in result handler");
        }
    }
    auto* const slots = ctx->slots;
    cass_future_free(fut);
    delete ctx;
    slots->release();
}

/// Blocks until all @p concurrency permits have been re-acquired — i.e. every
/// outstanding callback has released its slot — then throws if any error was
/// recorded.
void drain_and_check(std::counting_semaphore<>& slots, int concurrency,
                     CallbackErr& err, std::string_view where) {
    for (int i = 0; i < concurrency; ++i) slots.acquire();
    if (err.any()) [[unlikely]]
        throw std::runtime_error(std::string(where) + ": " + err.take());
}

/// Runs async tasks; dispatches results to @c handle when set (partition SELECT).
void run_async_tasks(int max_concurrency, const std::vector<AsyncTask>& tasks,
                     std::string_view where) {
    if (tasks.empty()) return;
    if (max_concurrency <= 0) {
        std::vector<FuturePtr> futs;
        futs.reserve(tasks.size());
        for (const auto& task : tasks) futs.push_back(task.submit());
        for (std::size_t i = 0; i < futs.size(); ++i) {
            wait_check(futs[i].get(), std::string(where));
            if (tasks[i].handle) {
                ResultPtr res{cass_future_get_result(futs[i].get())};
                tasks[i].handle(res.get());
            }
        }
        return;
    }
    std::counting_semaphore<> slots(max_concurrency);
    CallbackErr               err;
    for (const auto& task : tasks) {
        slots.acquire();
        if (err.any()) [[unlikely]] { slots.release(); break; }
        CassFuture* fut = task.submit().release();
        auto* ctx       = new AsyncCtx{task.handle, &slots, &err};
        if (cass_future_set_callback(fut, &on_async_done, ctx) != CASS_OK) [[unlikely]] {
            delete ctx;
            cass_future_free(fut);
            slots.release();
            err.record("cass_future_set_callback failed");
            break;
        }
    }
    drain_and_check(slots, max_concurrency, err, where);
}

std::optional<KeyMeta> fetch_meta(CassSession* session, const CassPrepared* select_meta,
                                  std::span<const std::uint8_t> key,
                                  std::string_view where) {
    StatementPtr meta_stmt{cass_prepared_bind(select_meta)};
    bind_blob(meta_stmt.get(), 0, key);
    FuturePtr meta_fut{cass_session_execute(session, meta_stmt.get())};
    wait_check(meta_fut.get(), std::string(where));
    ResultPtr      meta_res{cass_future_get_result(meta_fut.get())};
    const CassRow* meta_row = cass_result_first_row(meta_res.get());
    if (!meta_row) return std::nullopt;
    return KeyMeta(get_int32(cass_row_get_column(meta_row, 0)), get_int32(cass_row_get_column(meta_row, 1)));
}

std::vector<AsyncTask> partition_select_tasks(
    CassSession* session, const CassPrepared* select_partition,
    std::span<const std::uint8_t> key, int salt_count, const PartitionHandler& on_partition) {
    std::vector<AsyncTask> tasks;
    if (salt_count <= 0) return tasks;
    tasks.reserve(static_cast<std::size_t>(salt_count));
    for (int s : std::views::iota(0, salt_count)) {
        tasks.push_back({
            .submit = [session, select_partition, key, s] {
                StatementPtr stmt{cass_prepared_bind(select_partition)};
                bind_blob(stmt.get(), 0, key);
                cass_statement_bind_int32(stmt.get(), 1, s);
                return FuturePtr{cass_session_execute(session, stmt.get())};
            },
            .handle = [on_partition, s](const CassResult* res) { on_partition(s, res); },
        });
    }
    return tasks;
}

}  // namespace

// ---------------------------------------------------------------------------
// BlobLayout
// ---------------------------------------------------------------------------

/// Sums the @c bytes field of every PartitionInfo using a C++23 ranges pipeline:
///   - views::transform extracts the scalar member via pointer-to-member
///   - ranges::fold_left reduces with std::plus (replaces std::accumulate)
std::size_t BlobLayout::total_bytes() const noexcept {
    return std::ranges::fold_left(
        partitions | std::views::transform(&PartitionInfo::bytes),
        0uz, std::plus{});
}

// ---------------------------------------------------------------------------
// SaltedBlobStore — lifecycle
// ---------------------------------------------------------------------------

SaltedBlobStore::SaltedBlobStore(CassSession* session, std::string keyspace, std::string table)
    : session_(session), keyspace_(std::move(keyspace)), table_(std::move(table)) {}

SaltedBlobStore::~SaltedBlobStore() {
    release_prepared_();
}

/// Frees each non-null CassPrepared handle and resets the pointer to nullptr.
/// Called from the destructor and from drop_schema() so that the object can be
/// reused after the schema is recreated.
void SaltedBlobStore::release_prepared_() {
    if (p_insert_)           { cass_prepared_free(p_insert_);           p_insert_ = nullptr; }
    if (p_select_meta_)      { cass_prepared_free(p_select_meta_);      p_select_meta_ = nullptr; }
    if (p_select_partition_) { cass_prepared_free(p_select_partition_); p_select_partition_ = nullptr; }
    if (p_delete_partition_) { cass_prepared_free(p_delete_partition_); p_delete_partition_ = nullptr; }
}

/// Constructs a zero-parameter statement from @p cql, executes it
/// synchronously, and waits for the result.  Used for DDL (CREATE / DROP)
/// where no bound values are needed.
void SaltedBlobStore::execute_simple_(const std::string& cql) {
    StatementPtr stmt{cass_statement_new(cql.c_str(), 0)};
    FuturePtr    fut{cass_session_execute(session_, stmt.get())};
    wait_check(fut.get(), cql);
}

// ---------------------------------------------------------------------------
// SaltedBlobStore — schema management
// ---------------------------------------------------------------------------

/// Issues CREATE KEYSPACE IF NOT EXISTS and CREATE TABLE IF NOT EXISTS, then
/// calls prepare_() to ready the driver-side prepared statements.
/// @p rf is forwarded into the SimpleStrategy replication option.
void SaltedBlobStore::create_schema(int rf) {
    execute_simple_(std::format(
        "CREATE KEYSPACE IF NOT EXISTS {} "
        "WITH replication = {{'class':'SimpleStrategy','replication_factor':{}}}",
        keyspace_, rf));
    execute_simple_(std::format(
        "CREATE TABLE IF NOT EXISTS {}.{}"
        " (key blob, salt int, chunk_id int, chunk blob,"
        "  total_chunks int, salt_cardinality int,"
        "  PRIMARY KEY ((key, salt), chunk_id))",
        keyspace_, table_));
    prepare_();
}

/// Drops the entire keyspace unconditionally and releases prepared statements
/// so this object can be pointed at a freshly created schema.
void SaltedBlobStore::drop_schema() {
    execute_simple_("DROP KEYSPACE IF EXISTS " + keyspace_);
    release_prepared_();
}

/// Prepares the four CQL statements used by write / read / erase / describe.
/// Guards against double-preparation with an early-return when p_insert_ is
/// already set — all four are prepared atomically, so checking one is enough.
void SaltedBlobStore::prepare_() {
    if (p_insert_) return;
    const std::string ks_t = std::format("{}.{}", keyspace_, table_);
    p_insert_ = prepare_one(session_, std::format(
        "INSERT INTO {} (key, salt, chunk_id, chunk, total_chunks, salt_cardinality)"
        " VALUES (?, ?, ?, ?, ?, ?)", ks_t));
    p_select_meta_ = prepare_one(session_, std::format(
        "SELECT total_chunks, salt_cardinality FROM {}"
        " WHERE key = ? AND salt = 0 AND chunk_id = 0", ks_t));
    p_select_partition_ = prepare_one(session_, std::format(
        "SELECT chunk_id, chunk FROM {} WHERE key = ? AND salt = ?", ks_t));
    p_delete_partition_ = prepare_one(session_, std::format(
        "DELETE FROM {} WHERE key = ? AND salt = ?", ks_t));
}

// ---------------------------------------------------------------------------
// SaltedBlobStore::write
// ---------------------------------------------------------------------------

/// Splits @p blob into @p chunk_size byte pieces and distributes them across
/// up to @p max_salt CQL partitions identified by (key, salt).
///
/// Algorithm:
///   1. Empty blob: write a single sentinel row at (salt=0, chunk_id=0) with
///      total_chunks=0, salt_cardinality=1, and return.
///   2. Non-empty blob: compute num_chunks = ceil(blob.size / chunk_size) and
///      sc = min(num_chunks, max_salt).
///   3. Assign each chunk_id to salt = chunk_id % sc, giving a balanced
///      distribution.
///   4. For each salt, build UNLOGGED batches of INSERT statements, flushing
///      whenever the accumulated payload would exceed max_batch_bytes.
///   5. All batch futures are collected first, then awaited together, so
///      partitions are written in parallel.
///
/// The sentinel row is always at (salt=0, chunk_id=0) and carries
/// total_chunks and salt_cardinality for later reads.
void SaltedBlobStore::write(std::span<const std::uint8_t> key,
                            std::span<const std::uint8_t> blob,
                            int         max_salt,
                            std::size_t chunk_size,
                            std::size_t max_batch_bytes,
                            int         max_concurrency) {
    if (max_salt < 1)              throw std::invalid_argument("max_salt must be >= 1");
    if (chunk_size < 1)            throw std::invalid_argument("chunk_size must be >= 1");
    if (max_batch_bytes < 1)       throw std::invalid_argument("max_batch_bytes must be >= 1");
    if (max_concurrency < 0)       throw std::invalid_argument("max_concurrency must be >= 0");
    if (max_batch_bytes < chunk_size)
        throw std::invalid_argument("max_batch_bytes must be >= chunk_size");
    prepare_();

    if (blob.empty()) {
        StatementPtr stmt{cass_prepared_bind(p_insert_)};
        bind_blob(stmt.get(), 0, key);
        cass_statement_bind_int32(stmt.get(), 1, 0);
        cass_statement_bind_int32(stmt.get(), 2, 0);
        bind_blob(stmt.get(), 3, {});
        cass_statement_bind_int32(stmt.get(), 4, 0);
        cass_statement_bind_int32(stmt.get(), 5, 1);
        FuturePtr fut{cass_session_execute(session_, stmt.get())};
        wait_check(fut.get(), "INSERT sentinel (empty blob)");
        return;
    }

    const std::size_t num_chunks = (blob.size() + chunk_size - 1uz) / chunk_size;
    const int sc = static_cast<int>(
        std::min(num_chunks, static_cast<std::size_t>(max_salt)));

    // groups[salt] holds all chunk_ids assigned to that salt partition,
    // built with a ranges pipeline that round-robins chunk ids across salts.
    std::vector<std::vector<int>> groups(sc);
    for (int cid : std::views::iota(0, static_cast<int>(num_chunks)))
        groups[cid % sc].push_back(cid);

    auto chunk_view = [&](int cid) -> std::span<const std::uint8_t> {
        const std::size_t off = static_cast<std::size_t>(cid) * chunk_size;
        return blob.subspan(off, std::min(chunk_size, blob.size() - off));
    };

    std::vector<AsyncTask> tasks;
    for (int salt : std::views::iota(0, sc)) {
        BatchPtr    batch{cass_batch_new(CASS_BATCH_TYPE_UNLOGGED)};
        std::size_t batch_bytes    = 0uz;
        bool        batch_has_rows = false;

        for (int cid : groups[salt]) {
            const auto chunk = chunk_view(cid);
            if (batch_has_rows && batch_bytes + chunk.size() > max_batch_bytes) {
                // This is needed because FutureTask is an std::function and it has to be copyable,
                // which std::unique_ptr isn't.
                auto shared_batch = std::shared_ptr<CassBatch>(batch.release(), cass_batch_free);
                tasks.push_back({
                    .submit = [session = session_, shared_batch] {
                        return FuturePtr{cass_session_execute_batch(session, shared_batch.get())};
                    },
                });
                batch          = BatchPtr{cass_batch_new(CASS_BATCH_TYPE_UNLOGGED)};
                batch_bytes    = 0uz;
                batch_has_rows = false;
            }
            StatementPtr stmt{cass_prepared_bind(p_insert_)};
            bind_blob(stmt.get(), 0, key);
            cass_statement_bind_int32(stmt.get(), 1, salt);
            cass_statement_bind_int32(stmt.get(), 2, cid);
            bind_blob(stmt.get(), 3, chunk);
            cass_statement_bind_int32(stmt.get(), 4, static_cast<cass_int32_t>(num_chunks));
            cass_statement_bind_int32(stmt.get(), 5, static_cast<cass_int32_t>(sc));
            cass_batch_add_statement(batch.get(), stmt.get());
            batch_bytes   += chunk.size();
            batch_has_rows = true;
        }
        if (batch_has_rows) {
            auto shared_batch = std::shared_ptr<CassBatch>(batch.release(), cass_batch_free);
            tasks.push_back({
                .submit = [session = session_, shared_batch] {
                    return FuturePtr{cass_session_execute_batch(session, shared_batch.get())};
                },
            });
        }
    }
    run_async_tasks(max_concurrency, tasks, "INSERT batch");
}

// ---------------------------------------------------------------------------
// SaltedBlobStore::read
// ---------------------------------------------------------------------------

/// Reads the blob back as an ordered vector<Bytes> (one element per chunk_id):
///   1. Fetches the sentinel row (salt=0, chunk_id=0) for total_chunks and
///      salt_cardinality.  Returns std::nullopt immediately if the key does
///      not exist.
///   2. Returns an empty vector immediately when total_chunks == 0 (empty blob).
///   3. Issues one SELECT per salt partition.  When max_concurrency == 0 all
///      futures are fired at once and awaited in submission order; when
///      max_concurrency > 0 a sliding window (semaphore + callback) bounds
///      the number of in-flight futures.
///   4. Each result set is iterated and every chunk is placed directly into
///      chunks[chunk_id] in the pre-allocated output vector.
///   5. Verifies that every chunk was received: since the blob is non-empty,
///      every stored chunk has at least one byte, so any empty slot means a
///      missing chunk_id.
///   6. Returns the vector of chunks without concatenation — the caller
///      obtains a flat view via std::views::join if needed.
std::optional<std::vector<Bytes>> SaltedBlobStore::read(std::span<const std::uint8_t> key,
                                                        int max_concurrency) {
    prepare_();

    const auto meta = fetch_meta(session_, p_select_meta_, key, "SELECT meta");
    if (!meta) return std::nullopt;

    const cass_int32_t total_chunks     = meta->total_chunks;
    const cass_int32_t salt_cardinality = meta->salt_cardinality;
    if (total_chunks == 0)
        return std::vector<Bytes>{};
    const int salts = salt_cardinality;

    std::vector<Bytes> chunks(static_cast<std::size_t>(total_chunks));

    run_async_tasks(
        max_concurrency,
        partition_select_tasks(
            session_, p_select_partition_, key, salts,
            [&](int /*salt*/, const CassResult* res) {
                IteratorPtr it{cass_iterator_from_result(res)};
                while (cass_iterator_next(it.get())) {
                    const CassRow*     row  = cass_iterator_get_row(it.get());
                    const cass_int32_t cid  = get_int32(cass_row_get_column(row, 0));
                    const cass_byte_t* data = nullptr;
                    std::size_t        len  = 0uz;
                    cass_value_get_bytes(cass_row_get_column(row, 1), &data, &len);
                    if (cid < 0 || cid >= total_chunks)
                        throw std::runtime_error("chunk_id out of range");
                    if (len == 0uz)
                        throw std::runtime_error(std::format("chunk_id {}: corrupt chunk row (empty payload)", cid));
                    chunks[static_cast<std::size_t>(cid)].assign(data, data + len);
                }
            }),
        "SELECT partition");

    if (const auto miss = std::ranges::find_if(chunks, &Bytes::empty);
        miss != chunks.end()) [[unlikely]]
        throw std::runtime_error(std::format("missing chunk_id {} of {}",
                                             std::distance(chunks.begin(), miss),
                                             total_chunks));

    return chunks;
}

// ---------------------------------------------------------------------------
// SaltedBlobStore::erase
// ---------------------------------------------------------------------------

/// Deletes all CQL partitions associated with @p key.
///
/// Reads the sentinel row to learn the salt cardinality, then issues one
/// DELETE per partition.  Non-sentinel partitions (salt > 0) are removed
/// first; salt=0 (the metadata row) is always deleted last so a failed erase
/// can be retried.  If the key does not exist (no sentinel row), returns
/// silently — idempotent by design.
void SaltedBlobStore::erase(std::span<const std::uint8_t> key, int max_concurrency) {
    prepare_();

    const auto meta = fetch_meta(session_, p_select_meta_, key, "SELECT meta (erase)");
    if (!meta) return;

    const int salt_count = meta->salt_cardinality;

    auto delete_tasks = [&](int first, int last) -> std::vector<AsyncTask> {
        std::vector<AsyncTask> tasks;
        tasks.reserve(static_cast<std::size_t>(last - first));
        for (int s : std::views::iota(first, last)) {
            tasks.push_back({
                .submit = [session = session_, p_delete = p_delete_partition_, key, s] {
                    StatementPtr stmt{cass_prepared_bind(p_delete)};
                    bind_blob(stmt.get(), 0, key);
                    cass_statement_bind_int32(stmt.get(), 1, s);
                    return FuturePtr{cass_session_execute(session, stmt.get())};
                },
            });
        }
        return tasks;
    };

    run_async_tasks(max_concurrency, delete_tasks(1, salt_count), "DELETE partition");
    run_async_tasks(max_concurrency, delete_tasks(0, 1), "DELETE partition");
}

// ---------------------------------------------------------------------------
// SaltedBlobStore::describe
// ---------------------------------------------------------------------------

/// Queries each salt partition and accumulates row count and total chunk bytes
/// into a PartitionInfo per salt.  When @p max_concurrency == 0 all SELECTs are
/// fired at once; when @p max_concurrency > 0 a sliding window bounds in-flight
/// futures (same pattern as read).
std::optional<BlobLayout> SaltedBlobStore::describe(std::span<const std::uint8_t> key,
                                                    int max_concurrency) {
    prepare_();

    const auto meta = fetch_meta(session_, p_select_meta_, key, "SELECT meta (describe)");
    if (!meta) return std::nullopt;

    BlobLayout layout{
        .total_chunks     = meta->total_chunks,
        .salt_cardinality = meta->salt_cardinality,
    };
    const int salts = layout.salt_cardinality;
    layout.partitions.resize(static_cast<std::size_t>(salts));

    run_async_tasks(
        max_concurrency,
        partition_select_tasks(
            session_, p_select_partition_, key, salts,
            [&](int salt, const CassResult* res) {
                IteratorPtr it{cass_iterator_from_result(res)};
                PartitionInfo info{.salt = salt};
                while (cass_iterator_next(it.get())) {
                    const CassRow*     row  = cass_iterator_get_row(it.get());
                    const cass_byte_t* data = nullptr;
                    std::size_t        len  = 0uz;
                    cass_value_get_bytes(cass_row_get_column(row, 1), &data, &len);
                    info.rows  += 1uz;
                    info.bytes += len;
                }
                layout.partitions[static_cast<std::size_t>(salt)] = info;
            }),
        "SELECT partition (describe)");

    return layout;
}

}  // namespace scs
