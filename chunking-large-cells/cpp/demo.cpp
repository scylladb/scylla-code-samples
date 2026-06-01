// End-to-end demo of the modified salting technique against ScyllaDB.
//
// Mirrors the Python demo in ../python/demo.py: writes three blobs of
// different sizes following the hybrid policy from the blog post, verifies
// each round-trip, and prints how the blob is laid out across salted
// partitions.

#include "salted_blob_store.h"

#include <cassandra.h>

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <format>
#include <print>
#include <random>
#include <ranges>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>
#include <algorithm>

namespace {

// ---------------------------------------------------------------------------
// Test-data helpers
// ---------------------------------------------------------------------------

/// Generates a deterministic, pseudo-random byte buffer of exactly @p size bytes.
///
/// The PRNG is seeded from @p seed_str via std::seed_seq, so the same
/// (seed, size) pair always produces identical bytes.  This lets the demo
/// verify round-trips without storing an expected value separately.
///
/// @param seed_str  Human-readable seed string (e.g. "large-key:seed").
/// @param size      Number of bytes to generate.
/// @return A Bytes vector of length @p size filled with pseudo-random data.
scs::Bytes deterministic_blob(std::string_view seed_str, std::size_t size) {
    std::seed_seq       seq(seed_str.begin(), seed_str.end());
    std::mt19937_64     rng(seq);
    scs::Bytes          out(size);
    std::size_t         i = 0uz;
    // Fill 8 bytes at a time for efficiency; the final partial word is handled
    // separately to avoid writing past the end of the buffer.
    while (i + 8uz <= size) {
        const std::uint64_t v = rng();
        std::memcpy(out.data() + i, &v, 8);
        i += 8uz;
    }
    // (size - i) is guaranteed to be less than 8 here.
    if (i < size) {
        const std::uint64_t v = rng();
        std::memcpy(out.data() + i, &v, size - i);
    }
    return out;
}

/// Computes a 64-bit FNV-1a hash of @p v.
///
/// FNV-1a is not cryptographically secure, but is fast and sufficient for a
/// demo fingerprint that confirms the round-trip did not corrupt the data.
/// The hash is printed as a hex digest in the output.
///
/// @param v  Byte span to hash.
/// @return   64-bit digest.
template <typename T>
concept uint8_range = std::ranges::range<T> &&
                      std::same_as<std::ranges::range_value_t<T>, std::uint8_t>;
template <uint8_range T>
std::uint64_t fnv1a64(T&& v) {
    std::uint64_t h = 0xcbf29ce484222325ULL;
    for (std::uint8_t b : v) {
        h ^= b;
        h *= 0x100000001b3ULL;
    }
    return h;
}

/// Formats a raw byte count as a human-readable IEC string (B / KiB / MiB …).
///
/// The value is divided by 1024 until it falls below 1024 or the largest
/// unit is reached.  The result is right-aligned in a 7-character field with
/// 2 decimal places, e.g. @c "   4.00 KiB".
///
/// @param n  Byte count to format.
/// @return   Formatted string, e.g. @c "  64.00 KiB".
std::string fmt_bytes(double n) {
    static constexpr std::array<std::string_view, 5> units{
        "B", "KiB", "MiB", "GiB", "TiB"};
    std::size_t u = 0uz;
    while (n >= 1024.0 && u + 1uz < units.size())
        { n /= 1024.0; ++u; }
    return std::format("{:7.2f} {}", n, units[u]);
}

/// Reinterprets the bytes of a @c string_view as a span of @c uint8_t.
///
/// Avoids constructing a @c std::vector<uint8_t> just to pass a string literal
/// as a SaltedBlobStore key.  The returned span's lifetime is tied to @p s.
///
/// @param s  Source string view.
/// @return   Non-owning span over the same bytes.
std::span<const std::uint8_t> as_key(std::string_view s) {
    return {reinterpret_cast<const std::uint8_t*>(s.data()), s.size()};
}

/// Returns the number of milliseconds elapsed since @p t0 using a monotonic clock.
///
/// @param t0  Start time obtained from std::chrono::steady_clock::now().
/// @return    Elapsed duration in milliseconds as a double.
double elapsed_ms(std::chrono::steady_clock::time_point t0) {
    return std::chrono::duration<double, std::milli>(
               std::chrono::steady_clock::now() - t0).count();
}

// ---------------------------------------------------------------------------
// Demo runner
// ---------------------------------------------------------------------------

/// Exercises a single write → read → verify → describe cycle.
///
/// Generates a deterministic blob of @p size bytes, writes it to @p store with
/// the supplied salting parameters, reads it back, and verifies content
/// integrity via FNV-1a fingerprinting.  Also calls describe() to show how the
/// blob is spread across partitions.  Throws on any mismatch or driver error.
///
/// @param store       SaltedBlobStore instance to operate on.
/// @param name        Human-readable label printed as the section heading.
/// @param key_str     CQL blob key (passed as a string-view-derived span).
/// @param size        Blob size in bytes.
/// @param max_salt    Maximum salt cardinality for the write call.
/// @param chunk_size  Chunk size in bytes for the write call.
/// @throws std::runtime_error if the round-trip fingerprint does not match.
void run_case(scs::SaltedBlobStore& store,
              std::string_view       name,
              std::string_view       key_str,
              std::size_t            size,
              int                    max_salt,
              std::size_t            chunk_size,
              int                    max_concurrency) {
    const auto          key    = as_key(key_str);
    const scs::Bytes    blob   = deterministic_blob(
                                     std::format("{}:seed", key_str), size);
    const std::uint64_t fp_in  = fnv1a64(blob);

    std::println("\n=== {} ===", name);
    std::println("  key        : {}", key_str);
    std::println("  size       : {}", fmt_bytes(static_cast<double>(blob.size())));
    std::println("  max_salt   : {}", max_salt);
    std::println("  chunk_size : {}", fmt_bytes(static_cast<double>(chunk_size)));
    std::println("  fnv1a(in)  : 0x{:016x}", fp_in);

    auto t0 = std::chrono::steady_clock::now();
    store.write(key, blob, max_salt, chunk_size,
                scs::kDefaultMaxBatchBytes, max_concurrency);
    const double t_write = elapsed_ms(t0);

    t0 = std::chrono::steady_clock::now();
    auto out = store.read(key, max_concurrency);
    const double t_read = elapsed_ms(t0);

    if (!out) throw std::runtime_error("blob unexpectedly missing after write");
    const std::uint64_t fp_out = fnv1a64((*out | std::views::join));
    std::println("  fnv1a(out) : 0x{:016x}", fp_out);
    std::println("  write      : {:8.1f} ms", t_write);
    std::println("  read       : {:8.1f} ms", t_read);
    if (!std::ranges::equal((*out | std::views::join), blob)) throw std::runtime_error("round-trip digest mismatch");
    std::println("  round-trip : OK");

    // Print the partition layout, capping the per-partition list at 5 rows to
    // keep output manageable for highly-salted blobs.
    if (auto layout = store.describe(key, max_concurrency)) {
        std::println("  layout     : total_chunks={}, salt_cardinality={}, stored_bytes={}",
                     layout->total_chunks, layout->salt_cardinality,
                     fmt_bytes(static_cast<double>(layout->total_bytes())));
        constexpr std::size_t kMaxShown = 5uz;
        const std::size_t shown = std::min(kMaxShown, layout->partitions.size());
        for (const auto& p : layout->partitions | std::views::take(shown))
            std::println("    salt={:3d}  rows={:4}  bytes={}",
                         p.salt, p.rows,
                         fmt_bytes(static_cast<double>(p.bytes)));
        if (layout->partitions.size() > shown)
            std::println("    ... ({} more salted partitions)",
                         layout->partitions.size() - shown);
    }
}

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

/// Holds all command-line (and environment-variable) configuration for the demo.
struct Args {
    std::string contact_points = "127.0.0.1";  ///< Comma-separated list of ScyllaDB contact points.
    int         port           = 9042;          ///< Native CQL port.
    std::string username;                       ///< CQL username (empty = no authentication).
    std::string password;                       ///< CQL password (empty = no authentication).
    std::string keyspace       = "salted_blob_demo"; ///< Keyspace to create / use.
    std::string table          = "salted_blobs";     ///< Table to create / use within the keyspace.
    int         rf             = 1;             ///< Replication factor for CREATE KEYSPACE.
    int         large_mb       = 8;             ///< Size in MiB for the large-blob test case.
    int         max_concurrency = scs::kDefaultMaxConcurrency; ///< Max in-flight CQL futures per store call (0 = unlimited).
    bool        cleanup        = false;         ///< If true, DROP KEYSPACE after all test cases.
};

/// Prints a brief usage message to stdout and exits with @p rc.
/// Declared [[noreturn]] because std::exit never returns.
[[noreturn]] void usage(int rc) {
    std::println(
        "Usage: demo [--contact-points HOSTS] [--port N] [--username U] [--password P]\n"
        "            [--keyspace KS] [--table T] [--rf N] [--large-mb N]\n"
        "            [--max-concurrency N] [--cleanup]");
    std::exit(rc);
}

/// Parses command-line arguments into an Args struct.
///
/// Environment variables are read first as defaults; CLI flags override them.
/// Recognised environment variables:
///   - SCYLLA_CONTACT_POINTS
///   - SCYLLA_PORT
///   - SCYLLA_USERNAME
///   - SCYLLA_PASSWORD
///
/// @param argc  Argument count from main.
/// @param argv  Argument vector from main.
/// @return      Fully populated Args.
/// @note Calls usage(2) and exits on unknown flags or missing values.
Args parse(int argc, char** argv) {
    Args a;
    if (const char* e = std::getenv("SCYLLA_CONTACT_POINTS")) a.contact_points = e;
    if (const char* e = std::getenv("SCYLLA_PORT"))           a.port = std::atoi(e);
    if (const char* e = std::getenv("SCYLLA_USERNAME"))       a.username = e;
    if (const char* e = std::getenv("SCYLLA_PASSWORD"))       a.password = e;

    // Retrieves the value for the next argv token; exits with usage(2) if none.
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
        else if (s == "--table")          a.table          = need(i, "--table");
        else if (s == "--rf")             a.rf             = std::stoi(need(i, "--rf"));
        else if (s == "--large-mb")        a.large_mb        = std::stoi(need(i, "--large-mb"));
        else if (s == "--max-concurrency") a.max_concurrency = std::stoi(need(i, "--max-concurrency"));
        else if (s == "--cleanup")         a.cleanup         = true;
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

/// Sets up a CassCluster and CassSession, creates the schema, and runs
/// three test cases (small / medium / large blob) plus a missing-key probe
/// and an erase verification.
///
/// Returns 0 on success or 1 if the connection fails or any test case throws.
/// The CassSession and CassCluster are freed unconditionally before exit so
/// the driver can flush any pending work.
int main(int argc, char** argv) {
    const Args args = parse(argc, argv);

    CassCluster* cluster = cass_cluster_new();
    CassSession* session = cass_session_new();
    cass_cluster_set_contact_points(cluster, args.contact_points.c_str());
    cass_cluster_set_port(cluster, args.port);
    // CQL native protocol v4 — required for Scylla shard-aware routing.
    cass_cluster_set_protocol_version(cluster, 4);
    // Token-aware routing sends each request directly to the owning shard,
    // avoiding an extra coordinator hop.
    cass_cluster_set_token_aware_routing(cluster, cass_true);
    if (!args.username.empty())
        cass_cluster_set_credentials(cluster, args.username.c_str(), args.password.c_str());

    int rc_main = 0;
    CassFuture* connect = cass_session_connect(session, cluster);
    cass_future_wait(connect);
    if (cass_future_error_code(connect) != CASS_OK) {
        const char* msg     = nullptr;
        std::size_t msg_len = 0uz;
        cass_future_error_message(connect, &msg, &msg_len);
        std::println(stderr, "connect failed: {}", std::string_view{msg, msg_len});
        rc_main = 1;
    }
    cass_future_free(connect);

    if (rc_main == 0) {
        try {
            scs::SaltedBlobStore store(session, args.keyspace, args.table);
            store.create_schema(args.rf);

            // Small blob: fits in a single chunk, no salting required.
            run_case(store, "small blob (no chunking)",
                     "small-key",  2uz * 1024,   1,   4096uz, args.max_concurrency);
            // Medium blob: a handful of salts demonstrates the distribution.
            run_case(store, "medium blob (a few salts)",
                     "medium-key", 256uz * 1024, 8,   4096uz, args.max_concurrency);
            // Large blob: high salt cardinality with larger chunks to reduce row count.
            run_case(store,
                     std::format("large blob (high salting, {} MiB)", args.large_mb),
                     "large-key",
                     static_cast<std::size_t>(args.large_mb) * 1024uz * 1024uz,
                     100, 64uz * 1024, args.max_concurrency);

            // Verify that a lookup for an absent key returns std::nullopt.
            std::println("\n=== missing key ===");
            const auto missing = store.read(as_key("does-not-exist"));
            std::println("  read(missing) -> {}",
                         missing ? "<some bytes>" : "<nullopt>");

            // Verify that erase makes a key unreadable.
            std::println("\n=== delete medium-key ===");
            store.erase(as_key("medium-key"), args.max_concurrency);
            const auto after = store.read(as_key("medium-key"));
            std::println("  read(medium-key) -> {}",
                         after ? "<some bytes>" : "<nullopt>");

            if (args.cleanup) {
                std::println("\nCleaning up keyspace...");
                store.drop_schema();
            }
        } catch (const std::exception& ex) {
            std::println(stderr, "Demo failed: {}", ex.what());
            rc_main = 1;
        }
    }

    // Always close the session gracefully so the driver can drain in-flight
    // requests and free its internal thread pool.
    CassFuture* close = cass_session_close(session);
    cass_future_wait(close);
    cass_future_free(close);
    cass_session_free(session);
    cass_cluster_free(cluster);
    return rc_main;
}
