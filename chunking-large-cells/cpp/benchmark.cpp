// Large-blob vs small-blob benchmark for ScyllaDB.
//
// Mirrors ../python/benchmark.py.
//
// Compares the same total byte volume written and read in two ways:
//
//   LARGE BLOB CASE
//     --count blobs, each --large-mb MiB, stored via Modified-Salting
//     (SaltedBlobStore: chunked across multiple partitions, reads/writes
//     parallelised internally with async CQL).  One write() or read() call
//     constitutes a single "operation" whose wall-clock time is measured.
//
//   SMALL BLOB CASE
//     ceil(count * large_mb / small_kb) blobs, each --small-kb KiB, stored
//     as a single row per blob (one CQL INSERT or SELECT per operation).
//     A sliding async window of --concurrency outstanding requests drives
//     throughput.
//
// The final report shows per-operation latency (min / p50 / p99 / max) and
// aggregate throughput (MiB/s) side-by-side for both cases.
//
// Defaults: 1,000 × 30 MiB large blobs  ≈ 29.3 GiB total
//           matched by ~480,000 × 64 KiB small blobs
// WARNING : 1,000 × 30 MiB requires ~30 GiB of free disk space on ScyllaDB.
//           Use --count 10 (or --count 100) for a faster smoke-test.

#include "salted_blob_store.h"

#include <cassandra.h>

#include <algorithm>
#include <atomic>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <format>
#include <memory>
#include <mutex>
#include <optional>
#include <print>
#include <random>
#include <ranges>
#include <semaphore>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

// ---------------------------------------------------------------------------
// RAII wrappers (same pattern as salted_blob_store.cpp)
// ---------------------------------------------------------------------------

template <auto Free>
struct CassDeleter {
    template <typename T> void operator()(T* p) const noexcept { Free(p); }
};

template <typename T, auto Free>
using CassUnique = std::unique_ptr<T, CassDeleter<Free>>;

using FuturePtr   = CassUnique<CassFuture,         cass_future_free>;
using StmtPtr     = CassUnique<CassStatement,      cass_statement_free>;
using PreparedPtr = CassUnique<const CassPrepared, cass_prepared_free>;

// ---------------------------------------------------------------------------
// Driver helpers
// ---------------------------------------------------------------------------

[[noreturn]] void throw_future_error(CassFuture* f, std::string_view where) {
    const char* msg     = nullptr;
    std::size_t msg_len = 0uz;
    cass_future_error_message(f, &msg, &msg_len);
    throw std::runtime_error(
        std::format("{}: {}", where, std::string_view{msg, msg_len}));
}

void wait_check(CassFuture* f, std::string_view where) {
    cass_future_wait(f);
    if (cass_future_error_code(f) != CASS_OK) [[unlikely]]
        throw_future_error(f, where);
}

void execute_simple(CassSession* session, const std::string& cql) {
    StmtPtr   stmt{cass_statement_new(cql.c_str(), 0)};
    FuturePtr fut{cass_session_execute(session, stmt.get())};
    wait_check(fut.get(), cql);
}

PreparedPtr prepare_stmt(CassSession* session, const std::string& cql) {
    FuturePtr fut{cass_session_prepare(session, cql.c_str())};
    wait_check(fut.get(), "PREPARE " + cql);
    return PreparedPtr{cass_future_get_prepared(fut.get())};
}

void bind_blob(CassStatement* stmt, std::size_t idx,
               std::span<const std::uint8_t> data) {
    static constexpr std::uint8_t empty = 0;
    cass_statement_bind_bytes(stmt, idx,
                              data.empty() ? &empty : data.data(),
                              data.size());
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

std::string make_ruler(int n = 72) {
    std::string r;
    r.reserve(static_cast<std::size_t>(n) * 3uz);
    for (int i = 0; i < n; ++i) r += "━";
    return r;
}
const std::string kRuler = make_ruler();

// Formats a byte count as a human-readable IEC string (B / KiB / MiB …).
std::string fmt_bytes(double n) {
    static constexpr std::array<std::string_view, 6> units{
        "B", "KiB", "MiB", "GiB", "TiB", "PiB"};
    std::size_t u = 0uz;
    while (std::abs(n) >= 1024.0 && u + 1uz < units.size())
        { n /= 1024.0; ++u; }
    return std::format("{:.2f} {}", n, units[u]);
}

// Formats a duration in milliseconds; switches to seconds above 1 000 ms.
std::string fmt_ms(double ms) {
    return ms < 1000.0 ? std::format("{:.1f} ms", ms)
                       : std::format("{:.2f} s",  ms / 1000.0);
}

// Formats a duration in seconds; switches to "Xm Ys" above 60 s.
std::string fmt_s(double s) {
    if (s < 60.0) return std::format("{:.1f} s", s);
    return std::format("{}m {:.0f}s",
                       static_cast<int>(s / 60.0), std::fmod(s, 60.0));
}

// Formats an integer with comma thousands separators (e.g. 1,234,567).
std::string fmt_count(std::size_t n) {
    std::string s = std::to_string(n);
    int pos = static_cast<int>(s.size()) - 3;
    while (pos > 0) { s.insert(static_cast<std::size_t>(pos), ","); pos -= 3; }
    return s;
}

// ---------------------------------------------------------------------------
// Percentile — linear interpolation, matches Python's implementation.
// Takes data by value so it can sort without disturbing the caller's vector.
// ---------------------------------------------------------------------------

double percentile(std::vector<double> data, double p) {
    if (data.empty()) return 0.0;
    std::ranges::sort(data);
    const double idx = p / 100.0 * static_cast<double>(data.size() - 1uz);
    const auto   lo  = static_cast<std::size_t>(idx);
    const auto   hi  = std::min(lo + 1uz, data.size() - 1uz);
    return data[lo] + (data[hi] - data[lo]) * (idx - static_cast<double>(lo));
}

// ---------------------------------------------------------------------------
// Progress bar — overwrites the current line via '\r'.
// ---------------------------------------------------------------------------

void print_progress(int done, int total,
                    std::chrono::steady_clock::time_point t_start) {
    const double elapsed = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t_start).count();
    const double frac = total > 0
                      ? static_cast<double>(done) / static_cast<double>(total)
                      : 0.0;
    const double eta  = frac > 0.0 ? elapsed / frac - elapsed : 0.0;

    constexpr int kWidth = 30;
    const int filled = static_cast<int>(kWidth * frac);
    std::string bar;
    bar.reserve(static_cast<std::size_t>(kWidth) * 3uz);
    for (int i = 0; i < filled;          ++i) bar += "█";
    for (int i = filled; i < kWidth; ++i) bar += "░";

    const int tw = static_cast<int>(std::to_string(total).size());
    std::print("\r  [{}] {:>{}}/{}  {:.0f}s elapsed  ~{:.0f}s left   ",
               bar, done, tw, total, elapsed, eta);
    std::fflush(stdout);
}

// ---------------------------------------------------------------------------
// Payload generation — pseudo-random, non-cryptographic.
// Content is irrelevant for an I/O benchmark; only byte count matters.
// ---------------------------------------------------------------------------

scs::Bytes make_payload(std::size_t size) {
    std::mt19937_64 rng{std::random_device{}()};
    scs::Bytes      buf(size);
    std::size_t     i = 0uz;
    while (i + 8uz <= size) {
        const std::uint64_t v = rng();
        std::memcpy(buf.data() + i, &v, 8);
        i += 8uz;
    }
    if (i < size) {
        const auto bytes = std::bit_cast<std::array<std::uint8_t, 8>>(rng());
        std::copy_n(bytes.begin(), size - i, buf.data() + i);
    }
    return buf;
}

// ---------------------------------------------------------------------------
// Benchmark result — per-operation latencies (ms) + total wall time (s).
// ---------------------------------------------------------------------------

struct BenchResult {
    std::vector<double> write_ms;
    std::vector<double> read_ms;
    double              write_wall_s = 0.0;
    double              read_wall_s  = 0.0;
};

// ---------------------------------------------------------------------------
// Large-blob benchmark
// ---------------------------------------------------------------------------

/// Writes then reads @p count large blobs via SaltedBlobStore.
/// Each write()/read() call is one measured operation.
BenchResult bench_large(scs::SaltedBlobStore&         store,
                        int                           count,
                        std::size_t                   blob_size,
                        int                           max_salt,
                        std::size_t                   chunk_size,
                        std::span<const std::uint8_t> payload,
                        int                           store_concurrency) {
    // Pre-build keys: "bench-large-0000001", "bench-large-0000002", …
    std::vector<std::string> keys;
    keys.reserve(static_cast<std::size_t>(count));
    for (int i : std::views::iota(0, count))
        keys.push_back(std::format("bench-large-{:07d}", i));

    const int report_step = std::max(1, count / 50);

    BenchResult res;
    res.write_ms.reserve(static_cast<std::size_t>(count));
    res.read_ms.reserve(static_cast<std::size_t>(count));

    // ── WRITE ────────────────────────────────────────────────────────────────
    std::println("\n{}", kRuler);
    std::println("  LARGE BLOB WRITE  —  {} × {}",
                 fmt_count(static_cast<std::size_t>(count)),
                 fmt_bytes(static_cast<double>(blob_size)));
    std::println("{}", kRuler);

    const auto t_write_wall = std::chrono::steady_clock::now();
    for (int i : std::views::iota(0, count)) {
        const auto key = std::span{
            reinterpret_cast<const std::uint8_t*>(keys[i].data()),
            keys[i].size()};
        const auto t0 = std::chrono::steady_clock::now();
        store.write(key, payload, max_salt, chunk_size,
                    scs::kDefaultMaxBatchBytes, store_concurrency);
        res.write_ms.push_back(std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - t0).count());
        if ((i + 1) % report_step == 0 || i + 1 == count)
            print_progress(i + 1, count, t_write_wall);
    }
    res.write_wall_s = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t_write_wall).count();
    std::println("\n  done in {}  ({}/s)",
                 fmt_s(res.write_wall_s),
                 fmt_bytes(static_cast<double>(count) *
                           static_cast<double>(blob_size) / res.write_wall_s));

    // ── READ ─────────────────────────────────────────────────────────────────
    std::println("\n{}", kRuler);
    std::println("  LARGE BLOB READ   —  {} × {}",
                 fmt_count(static_cast<std::size_t>(count)),
                 fmt_bytes(static_cast<double>(blob_size)));
    std::println("{}", kRuler);

    const auto t_read_wall = std::chrono::steady_clock::now();
    for (int i : std::views::iota(0, count)) {
        const auto key = std::span{
            reinterpret_cast<const std::uint8_t*>(keys[i].data()),
            keys[i].size()};
        const auto t0 = std::chrono::steady_clock::now();
        auto chunks = store.read(key, store_concurrency);
        res.read_ms.push_back(std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - t0).count());
        if (!chunks)
            throw std::runtime_error(
                std::format("missing blob for key '{}'", keys[i]));
        if ((i + 1) % report_step == 0 || i + 1 == count)
            print_progress(i + 1, count, t_read_wall);
    }
    res.read_wall_s = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t_read_wall).count();
    std::println("\n  done in {}  ({}/s)",
                 fmt_s(res.read_wall_s),
                 fmt_bytes(static_cast<double>(count) *
                           static_cast<double>(blob_size) / res.read_wall_s));

    return res;
}

// ---------------------------------------------------------------------------
// Small-blob async machinery
//
// Per-op state passed through the void* user-data slot of
// cass_future_set_callback. Lives on the heap; the callback owns it.
// ---------------------------------------------------------------------------

struct OpCtx {
    std::chrono::steady_clock::time_point t0;
    std::size_t                           op_idx;
    std::vector<double>*                  lats;       ///< Pre-sized; written at op_idx without lock.
    std::counting_semaphore<>*            slots;      ///< Released here → unblocks producer.
    std::atomic<int>*                     completed;  ///< Approximate progress counter.
    std::atomic<int>*                     errors;
    std::mutex*                           err_mutex;
    std::string*                          first_err;
};

/// Driver-thread completion callback.
///
/// Invoked exactly once per future. Marked noexcept because exceptions
/// thrown from a C-driver callback cannot propagate and would call
/// std::terminate anyway — making the intent explicit.
void on_op_done(CassFuture* fut, void* data) noexcept {
    auto* const ctx = static_cast<OpCtx*>(data);
    const double ms = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - ctx->t0).count();
    (*ctx->lats)[ctx->op_idx] = ms;

    if (cass_future_error_code(fut) != CASS_OK) [[unlikely]] {
        const char* msg = nullptr;
        std::size_t mlen = 0uz;
        cass_future_error_message(fut, &msg, &mlen);
        std::lock_guard lk{*ctx->err_mutex};
        if (ctx->first_err->empty())
            ctx->first_err->assign(msg, mlen);
        ctx->errors->fetch_add(1, std::memory_order_relaxed);
    }
    ctx->completed->fetch_add(1, std::memory_order_release);

    // Snapshot the semaphore pointer before deleting ctx; release() is the
    // last step so the producer can't observe ctx-not-yet-cleaned-up.
    auto* const slots = ctx->slots;
    cass_future_free(fut);
    delete ctx;
    slots->release();
}

// ---------------------------------------------------------------------------
// Small-blob benchmark
// ---------------------------------------------------------------------------

/// Writes then reads small blobs totalling @p total_bytes.
/// Each operation is a single CQL INSERT or SELECT, driven by a true
/// sliding-window of @p concurrency in-flight requests: the moment any
/// outstanding op completes, the producer wakes and issues the next one
/// (no batch-stalling).
BenchResult bench_small(CassSession*                  session,
                        std::string_view               keyspace,
                        std::size_t                    total_bytes,
                        std::size_t                    small_size,
                        std::span<const std::uint8_t>  payload,
                        int                            concurrency) {
    if (concurrency < 1) throw std::invalid_argument("concurrency must be >= 1");
    const int n_ops = static_cast<int>(
        (total_bytes + small_size - 1uz) / small_size);  // ceil

    // Pre-build keys: "bench-small-0000000001", …
    std::vector<std::string> keys;
    keys.reserve(static_cast<std::size_t>(n_ops));
    for (int i : std::views::iota(0, n_ops))
        keys.push_back(std::format("bench-small-{:010d}", i));

    execute_simple(session, std::format(
        "CREATE TABLE IF NOT EXISTS {}.small_blobs "
        "(key blob PRIMARY KEY, data blob)", keyspace));

    PreparedPtr stmt_w = prepare_stmt(session, std::format(
        "INSERT INTO {}.small_blobs (key, data) VALUES (?, ?)", keyspace));
    PreparedPtr stmt_r = prepare_stmt(session, std::format(
        "SELECT data FROM {}.small_blobs WHERE key = ?", keyspace));

    const int report_step = std::max(1, n_ops / 50);

    BenchResult res;
    res.write_ms.reserve(static_cast<std::size_t>(n_ops));
    res.read_ms.reserve(static_cast<std::size_t>(n_ops));

    // True sliding-window: the producer holds at most `concurrency` permits,
    // each completion's callback releases one. The producer therefore never
    // waits for a "round" to drain — as soon as any single op completes, the
    // next op is issued. `make_stmt(j)` returns a new CassStatement* owned by
    // the caller (wrapped in StmtPtr immediately).
    auto run_window = [&](auto make_stmt,
                          std::vector<double>& lats,
                          double& wall_s,
                          std::string_view heading) {
        std::println("\n{}", kRuler);
        std::println("{}", heading);
        std::println("{}", kRuler);

        lats.assign(static_cast<std::size_t>(n_ops), 0.0);

        std::counting_semaphore<> slots(concurrency);
        std::atomic<int>          completed{0};
        std::atomic<int>          errors{0};
        std::mutex                err_mutex;
        std::string               first_err;

        const auto t_wall        = std::chrono::steady_clock::now();
        int        last_reported = 0;

        // Issue loop: acquire a permit (blocks until one is free), then fire
        // the next op. The callback releases its permit on completion.
        int issued = 0;
        for (; issued < n_ops; ++issued) {
            slots.acquire();
            if (errors.load(std::memory_order_acquire) > 0) [[unlikely]] {
                slots.release();   // Permit unused — restore the invariant.
                break;
            }

            StmtPtr stmt{make_stmt(issued)};
            auto* const ctx = new OpCtx{
                .t0        = std::chrono::steady_clock::now(),
                .op_idx    = static_cast<std::size_t>(issued),
                .lats      = &lats,
                .slots     = &slots,
                .completed = &completed,
                .errors    = &errors,
                .err_mutex = &err_mutex,
                .first_err = &first_err,
            };
            CassFuture* const fut = cass_session_execute(session, stmt.get());
            if (cass_future_set_callback(fut, &on_op_done, ctx) != CASS_OK) [[unlikely]] {
                delete ctx;
                cass_future_free(fut);
                slots.release();
                std::lock_guard lk{err_mutex};
                if (first_err.empty()) first_err = "cass_future_set_callback failed";
                errors.fetch_add(1, std::memory_order_relaxed);
                break;
            }

            const int done_now = completed.load(std::memory_order_acquire);
            if (done_now >= last_reported + report_step) {
                print_progress(done_now, n_ops, t_wall);
                last_reported = done_now;
            }
        }

        // Drain: wait for every outstanding callback to release its permit.
        // try_acquire_for lets us also tick progress during the drain.
        int acquired = 0;
        while (acquired < concurrency) {
            if (slots.try_acquire_for(std::chrono::milliseconds(200)))
                ++acquired;
            const int done_now = completed.load(std::memory_order_acquire);
            if (done_now > last_reported) {
                print_progress(done_now, n_ops, t_wall);
                last_reported = done_now;
            }
        }

        wall_s = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - t_wall).count();
        print_progress(completed.load(), n_ops, t_wall);

        if (errors.load() > 0) [[unlikely]] {
            std::lock_guard lk{err_mutex};
            throw std::runtime_error(
                std::format("small blob op failed after {} issued: {}",
                            issued, first_err));
        }

        std::println("\n  done in {}  ({}/s)",
                     fmt_s(wall_s),
                     fmt_bytes(static_cast<double>(total_bytes) / wall_s));
    };

    // ── WRITE ────────────────────────────────────────────────────────────────
    run_window(
        [&](int j) -> CassStatement* {
            CassStatement* s = cass_prepared_bind(stmt_w.get());
            const auto key = std::span{
                reinterpret_cast<const std::uint8_t*>(keys[j].data()),
                keys[j].size()};
            bind_blob(s, 0, key);
            bind_blob(s, 1, payload);
            return s;
        },
        res.write_ms, res.write_wall_s,
        std::format("  SMALL BLOB WRITE  —  {} × {}  (concurrency={})",
                    fmt_count(static_cast<std::size_t>(n_ops)),
                    fmt_bytes(static_cast<double>(small_size)),
                    concurrency));

    // ── READ ─────────────────────────────────────────────────────────────────
    run_window(
        [&](int j) -> CassStatement* {
            CassStatement* s = cass_prepared_bind(stmt_r.get());
            const auto key = std::span{
                reinterpret_cast<const std::uint8_t*>(keys[j].data()),
                keys[j].size()};
            bind_blob(s, 0, key);
            return s;
        },
        res.read_ms, res.read_wall_s,
        std::format("  SMALL BLOB READ   —  {} × {}  (concurrency={})",
                    fmt_count(static_cast<std::size_t>(n_ops)),
                    fmt_bytes(static_cast<double>(small_size)),
                    concurrency));

    return res;
}

// ---------------------------------------------------------------------------
// Summary report
// ---------------------------------------------------------------------------

/// Prints the comparison table.
///
/// Either result may be std::nullopt (when --skip-large / --skip-small was
/// given); every cell that belongs to the skipped case shows "X".
/// @p n_small is the expected op count for the small case (used when
/// small is nullopt so the Op count row still shows a meaningful number).
void report(const std::optional<BenchResult>& large,
            const std::optional<BenchResult>& small,
            std::size_t                        large_blob_size,
            int                                large_count,
            std::size_t                        small_blob_size,
            std::size_t                        n_small) {
    const std::size_t total_bytes = static_cast<std::size_t>(large_count)
                                  * large_blob_size;
    const std::size_t small_count = small ? small->write_ms.size() : n_small;
    constexpr int C = 16;  // data column width

    // Returns "X" when the optional is empty; otherwise calls fn(*r).
    auto cell = [](const std::optional<BenchResult>& r,
                   auto fn) -> std::string {
        return r ? fn(*r) : "X";
    };

    auto throughput = [&](const std::optional<BenchResult>& r,
                          double BenchResult::* wall_s) -> std::string {
        return cell(r, [&](const BenchResult& b) -> std::string {
            const double w = b.*wall_s;
            if (w <= 0.0) return "—";
            return std::format("{:.1f} MiB/s",
                               static_cast<double>(total_bytes) / w /
                               (1024.0 * 1024.0));
        });
    };

    auto row = [C](std::string_view label,
                   std::string_view lw, std::string_view lr,
                   std::string_view sw, std::string_view sr) {
        std::println("  {:<32}  {:>{}}  {:>{}}  {:>{}}  {:>{}}",
                     label, lw, C, lr, C, sw, C, sr, C);
    };

    // lat_row: nullopt p → min; otherwise the given percentile.
    // Cells for skipped cases show "X".
    auto lat_cell = [](const std::optional<BenchResult>& r,
                       const std::vector<double> BenchResult::* vec,
                       std::optional<double> p) -> std::string {
        if (!r) return "X";
        const auto& v = r.value().*vec;
        if (v.empty()) return "X";
        return fmt_ms(p ? percentile(v, *p) : std::ranges::min(v));
    };

    auto lat_row = [&](std::string_view label, std::optional<double> p) {
        row(label,
            lat_cell(large, &BenchResult::write_ms, p),
            lat_cell(large, &BenchResult::read_ms,  p),
            lat_cell(small, &BenchResult::write_ms, p),
            lat_cell(small, &BenchResult::read_ms,  p));
    };

    auto max_cell = [](const std::optional<BenchResult>& r,
                       const std::vector<double> BenchResult::* vec)
            -> std::string {
        if (!r) return "X";
        const auto& v = r.value().*vec;
        return v.empty() ? "X" : fmt_ms(std::ranges::max(v));
    };

    const std::string sep_label(32, '-');
    const std::string sep_col(C,  '-');

    std::println("\n{}", kRuler);
    std::println("  BENCHMARK RESULTS");
    std::println("{}", kRuler);
    std::println("  Total payload   : {}  ({} × {} large  |  {} × {} small)",
                 fmt_bytes(static_cast<double>(total_bytes)),
                 fmt_count(static_cast<std::size_t>(large_count)),
                 fmt_bytes(static_cast<double>(large_blob_size)),
                 fmt_count(small_count),
                 fmt_bytes(static_cast<double>(small_blob_size)));
    std::println("");
    row("", "-- LARGE BLOB --", "READ", "-- SMALL BLOB --", "READ");
    row("", "WRITE", "", "WRITE", "");
    std::println("  {}  {}  {}  {}  {}",
                 sep_label, sep_col, sep_col, sep_col, sep_col);

    row("Throughput",
        throughput(large, &BenchResult::write_wall_s),
        throughput(large, &BenchResult::read_wall_s),
        throughput(small, &BenchResult::write_wall_s),
        throughput(small, &BenchResult::read_wall_s));
    std::println("");
    row("Total time",
        cell(large, [](const BenchResult& b) { return fmt_s(b.write_wall_s); }),
        cell(large, [](const BenchResult& b) { return fmt_s(b.read_wall_s);  }),
        cell(small, [](const BenchResult& b) { return fmt_s(b.write_wall_s); }),
        cell(small, [](const BenchResult& b) { return fmt_s(b.read_wall_s);  }));
    row("Op count",
        fmt_count(static_cast<std::size_t>(large_count)),
        fmt_count(static_cast<std::size_t>(large_count)),
        fmt_count(small_count),
        fmt_count(small_count));
    std::println("");
    std::println("  Per-op latency  "
                 "[large = one {} blob; small = one {} CQL op]",
                 fmt_bytes(static_cast<double>(large_blob_size)),
                 fmt_bytes(static_cast<double>(small_blob_size)));
    std::println("  {}  {}  {}  {}  {}",
                 sep_label, sep_col, sep_col, sep_col, sep_col);
    lat_row("  min", std::nullopt);
    lat_row("  p50", 50.0);
    lat_row("  p99", 99.0);
    row("  max",
        max_cell(large, &BenchResult::write_ms),
        max_cell(large, &BenchResult::read_ms),
        max_cell(small, &BenchResult::write_ms),
        max_cell(small, &BenchResult::read_ms));
    std::println("{}", kRuler);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

/// All command-line / environment-variable configuration.
struct Args {
    std::string contact_points = "127.0.0.1"; ///< Comma-separated ScyllaDB hosts.
    int         port           = 9042;         ///< CQL native port.
    std::string username;                      ///< CQL username (empty = no auth).
    std::string password;                      ///< CQL password.
    std::string keyspace       = "blob_bench"; ///< Keyspace to create / use.
    int         rf             = 1;            ///< Replication factor.
    int         count          = 1000;         ///< Number of large blobs.
    int         large_mb       = 30;           ///< Large blob size (MiB).
    int         small_kb       = 64;           ///< Small blob size (KiB).
    int         chunk_size_kb  = 64;           ///< Chunk size for SaltedBlobStore (KiB).
    int         max_salt       = 100;          ///< max_salt for SaltedBlobStore.
    int         concurrency       = 64;         ///< Async window for small-blob ops.
    int         store_concurrency = scs::kDefaultMaxConcurrency; ///< Max in-flight futures per SaltedBlobStore call (0 = unlimited).
    bool        skip_large     = false;        ///< Skip the large-blob benchmark.
    bool        skip_small     = false;        ///< Skip the small-blob benchmark.
    bool        cleanup        = false;        ///< DROP keyspace when finished.
};

[[noreturn]] void usage(int rc) {
    std::println(
        "Usage: benchmark [OPTIONS]\n"
        "\n"
        "Options:\n"
        "  --contact-points HOSTS   Comma-separated ScyllaDB host list (default: 127.0.0.1)\n"
        "  --port N                 CQL port (default: 9042)\n"
        "  --username U             CQL username\n"
        "  --password P             CQL password\n"
        "  --keyspace KS            Keyspace name (default: blob_bench)\n"
        "  --rf N                   Replication factor (default: 1)\n"
        "  --count N                Number of large blobs (default: 1000)\n"
        "  --large-mb N             Large blob size in MiB (default: 30)\n"
        "  --small-kb N             Small blob size in KiB (default: 64)\n"
        "  --chunk-size-kb N        Chunk size for SaltedBlobStore in KiB (default: 64)\n"
        "  --max-salt N             max_salt for SaltedBlobStore (default: 100)\n"
        "  --concurrency N          Async window for small-blob ops (default: 64)\n"
        "  --store-concurrency N    Max in-flight futures per SaltedBlobStore call, 0=unlimited (default: 0)\n"
        "  --skip-large             Skip the large-blob benchmark\n"
        "  --skip-small             Skip the small-blob benchmark\n"
        "  --cleanup                DROP keyspace when finished\n"
        "  -h, --help               Print this message and exit");
    std::exit(rc);
}

Args parse(int argc, char** argv) {
    Args a;
    if (const char* e = std::getenv("SCYLLA_CONTACT_POINTS")) a.contact_points = e;
    if (const char* e = std::getenv("SCYLLA_PORT"))           a.port = std::atoi(e);
    if (const char* e = std::getenv("SCYLLA_USERNAME"))       a.username = e;
    if (const char* e = std::getenv("SCYLLA_PASSWORD"))       a.password = e;

    auto need = [&](int& i, const char* opt) -> std::string {
        if (i + 1 >= argc) {
            std::println(stderr, "missing value for {}", opt);
            usage(2);
        }
        return argv[++i];
    };

    for (int i = 1; i < argc; ++i) {
        const std::string_view s = argv[i];
        if      (s == "--contact-points") a.contact_points = need(i, "--contact-points");
        else if (s == "--port")           a.port           = std::stoi(need(i, "--port"));
        else if (s == "--username")       a.username       = need(i, "--username");
        else if (s == "--password")       a.password       = need(i, "--password");
        else if (s == "--keyspace")       a.keyspace       = need(i, "--keyspace");
        else if (s == "--rf")             a.rf             = std::stoi(need(i, "--rf"));
        else if (s == "--count")          a.count          = std::stoi(need(i, "--count"));
        else if (s == "--large-mb")       a.large_mb       = std::stoi(need(i, "--large-mb"));
        else if (s == "--small-kb")       a.small_kb       = std::stoi(need(i, "--small-kb"));
        else if (s == "--chunk-size-kb")  a.chunk_size_kb  = std::stoi(need(i, "--chunk-size-kb"));
        else if (s == "--max-salt")       a.max_salt       = std::stoi(need(i, "--max-salt"));
        else if (s == "--concurrency")       a.concurrency       = std::stoi(need(i, "--concurrency"));
        else if (s == "--store-concurrency") a.store_concurrency = std::stoi(need(i, "--store-concurrency"));
        else if (s == "--skip-large")        a.skip_large        = true;
        else if (s == "--skip-small")     a.skip_small     = true;
        else if (s == "--cleanup")        a.cleanup        = true;
        else if (s == "-h" || s == "--help") usage(0);
        else {
            std::println(stderr, "unknown argument: {}", s);
            usage(2);
        }
    }
    return a;
}

}  // namespace

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int main(int argc, char** argv) {
    const Args a = parse(argc, argv);

    const std::size_t blob_size   = static_cast<std::size_t>(a.large_mb)     * 1024uz * 1024uz;
    const std::size_t small_size  = static_cast<std::size_t>(a.small_kb)     * 1024uz;
    const std::size_t chunk_size  = static_cast<std::size_t>(a.chunk_size_kb) * 1024uz;
    const std::size_t total_bytes = static_cast<std::size_t>(a.count) * blob_size;
    const std::size_t n_small     = (total_bytes + small_size - 1uz) / small_size;

    std::println("{}", kRuler);
    std::println("  ScyllaDB  ·  Large-vs-Small Blob Benchmark");
    std::println("{}", kRuler);
    std::println("  Large blobs  : {} × {} MiB  =  {} total",
                 fmt_count(static_cast<std::size_t>(a.count)), a.large_mb,
                 fmt_bytes(static_cast<double>(total_bytes)));
    std::println("  Small blobs  : {} × {} KiB  ≈  {} total",
                 fmt_count(n_small), a.small_kb,
                 fmt_bytes(static_cast<double>(n_small * small_size)));
    std::println("  Chunk size   : {} KiB   max_salt={}   concurrency={}   store-concurrency={}",
                 a.chunk_size_kb, a.max_salt, a.concurrency,
                 a.store_concurrency == 0 ? "unlimited" : std::to_string(a.store_concurrency));
    std::println("  ScyllaDB     : {}:{}   keyspace={}   rf={}",
                 a.contact_points, a.port, a.keyspace, a.rf);
    std::println("{}", kRuler);

    CassCluster* cluster = cass_cluster_new();
    CassSession* session = cass_session_new();
    cass_cluster_set_contact_points(cluster, a.contact_points.c_str());
    cass_cluster_set_port(cluster, a.port);
    cass_cluster_set_protocol_version(cluster, 4);
    cass_cluster_set_token_aware_routing(cluster, cass_true);
    if (!a.username.empty())
        cass_cluster_set_credentials(cluster,
                                     a.username.c_str(), a.password.c_str());

    int rc = 0;
    {
        CassFuture* cf = cass_session_connect(session, cluster);
        cass_future_wait(cf);
        if (cass_future_error_code(cf) != CASS_OK) {
            const char* msg     = nullptr;
            std::size_t msg_len = 0uz;
            cass_future_error_message(cf, &msg, &msg_len);
            std::println(stderr, "connect failed: {}",
                         std::string_view{msg, msg_len});
            rc = 1;
        }
        cass_future_free(cf);
    }

    if (rc == 0) {
        try {
            execute_simple(session, std::format(
                "CREATE KEYSPACE IF NOT EXISTS {} WITH replication = "
                "{{'class':'SimpleStrategy','replication_factor':{}}}",
                a.keyspace, a.rf));

            std::print("\n  Generating payload buffers...");
            std::fflush(stdout);
            const scs::Bytes large_payload = make_payload(blob_size);
            const auto       small_payload =
                std::span{large_payload}.first(small_size);
            std::println(" done.");

            std::optional<BenchResult> large_res;
            std::optional<BenchResult> small_res;

            if (!a.skip_large) {
                scs::SaltedBlobStore store(session, a.keyspace, "salted_blobs");
                store.create_schema(a.rf);
                large_res = bench_large(store, a.count, blob_size,
                                        a.max_salt, chunk_size, large_payload,
                                        a.store_concurrency);
            }

            if (!a.skip_small) {
                small_res = bench_small(session, a.keyspace, total_bytes,
                                        small_size, small_payload,
                                        a.concurrency);
            }

            report(large_res, small_res, blob_size, a.count, small_size, n_small);

            if (a.cleanup) {
                std::print("\n  Dropping keyspace {} ...", a.keyspace);
                std::fflush(stdout);
                execute_simple(session,
                               "DROP KEYSPACE IF EXISTS " + a.keyspace);
                std::println(" done.");
            }
        } catch (const std::exception& ex) {
            std::println(stderr, "Benchmark failed: {}", ex.what());
            rc = 1;
        }
    }

    CassFuture* close_fut = cass_session_close(session);
    cass_future_wait(close_fut);
    cass_future_free(close_fut);
    cass_session_free(session);
    cass_cluster_free(cluster);
    return rc;
}
