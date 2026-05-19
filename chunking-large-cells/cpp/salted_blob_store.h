/// @file salted_blob_store.h
/// @brief Modified salting technique for storing large blobs in ScyllaDB.
///
/// Each blob is split into fixed-size chunks and distributed across multiple
/// CQL partitions using a salt value.  Spreading data this way avoids hot
/// partitions and keeps individual rows well within ScyllaDB's recommended
/// cell-size limits.
///
/// Schema (created by SaltedBlobStore::create_schema):
/// @code
///   CREATE TABLE <ks>.<t> (
///       key              blob,
///       salt             int,
///       chunk_id         int,
///       chunk            blob,
///       total_chunks     int,
///       salt_cardinality int,
///       PRIMARY KEY ((key, salt), chunk_id)
///   );
/// @endcode
///
/// The sentinel row (salt=0, chunk_id=0) carries @c total_chunks and
/// @c salt_cardinality so readers can discover the full layout without
/// scanning empty partitions.
///
/// Reference: blog post "Storing large blobs in ScyllaDB".

#pragma once

#include <cassandra.h>

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <vector>

namespace scs {

/// @brief Default size of each chunk stored in a single CQL row (4 KiB).
///
/// Keeping chunks small limits the size of individual CQL cells, which
/// ScyllaDB handles efficiently.  Larger values reduce row count but increase
/// cell size; tune for your workload.
inline constexpr std::size_t kDefaultChunkSize = 4096uz;

/// @brief Default upper bound on the salt value (exclusive).
///
/// Actual salt cardinality is @c min(num_chunks, max_salt), so a blob with
/// fewer chunks than this limit uses a smaller cardinality automatically.
inline constexpr int kDefaultMaxSalt = 100;

/// @brief Maximum payload per UNLOGGED batch before it is flushed (1 MiB).
///
/// ScyllaDB rejects batches that exceed @c batch_size_fail_threshold_in_kb
/// (default 50 MiB).  This limit sits well below that threshold while still
/// amortising round-trip overhead for large blobs.
inline constexpr std::size_t kDefaultMaxBatchBytes = 1uz * 1024 * 1024;

/// @brief Maximum number of CQL futures that may be in-flight simultaneously.
///
/// Limits the number of concurrent batch executions (write) and partition
/// reads/deletes/describes (read, erase, describe).  A value of 0 means no limit — all futures
/// are issued at once, preserving the previous behaviour.
///
/// Tune downward if you observe driver-queue or server-side pressure; tune
/// upward (or leave at 0) when the number of salt partitions is bounded
/// naturally by @p kDefaultMaxSalt.
inline constexpr int kDefaultMaxConcurrency = 0;

/// @brief Owned byte buffer — the return type of SaltedBlobStore::read.
///
using Bytes = std::vector<std::uint8_t>;

/// @brief Per-partition storage statistics returned by SaltedBlobStore::describe.
///
struct PartitionInfo {
    int         salt  = 0;  ///< Salt value that identifies this partition.
    std::size_t rows  = 0;  ///< Number of chunk rows stored in this partition.
    std::size_t bytes = 0;  ///< Total raw chunk bytes stored in this partition.
};

/// @brief Full layout description of a stored blob.
///
/// Returned by SaltedBlobStore::describe.  @c partitions contains one entry
/// per salt value that was actually written; the sum of all @c bytes fields
/// equals the original blob size (excluding any padding for empty blobs).
struct BlobLayout {
    int                        total_chunks     = 0;  ///< Total number of chunks the blob was split into.
    int                        salt_cardinality = 0;  ///< Number of distinct salt partitions used.
    std::vector<PartitionInfo> partitions;            ///< Per-partition breakdown; one element per salt.

    /// @brief Sum of the raw chunk bytes across all partitions.
    ///
    /// @return Total stored byte count (may be 0 for an empty blob).
    ///
    std::size_t total_bytes() const noexcept;
};

/// @brief Read/write facade over the salted-blob schema.
///
/// @par Ownership
/// Does @b not own the @c CassSession.  The caller is responsible for
/// connecting and tearing it down; the session must outlive this object.
///
/// @par Thread safety
/// Not thread-safe.  Each thread should use its own instance.
///
/// @par Input buffers
/// All key and blob parameters are @c std::span<const uint8_t> so callers
/// can pass any contiguous buffer — @c std::vector, raw array,
/// @c string_view-derived pointer pair — without an extra copy.
class SaltedBlobStore {
public:
    /// @brief Constructs the store targeting the given keyspace and table.
    ///
    /// The constructor does @b not touch ScyllaDB.  Call create_schema() to
    /// create the keyspace/table and prepare the driver statements before
    /// performing any reads or writes.
    ///
    /// @param session   Connected CassSession (non-owning).
    /// @param keyspace  CQL keyspace name that contains (or will contain) the table.
    /// @param table     CQL table name (defaults to @c "salted_blobs").
    SaltedBlobStore(CassSession* session,
                    std::string  keyspace,
                    std::string  table = "salted_blobs");

    /// @brief Releases all driver-prepared statements.
    ///
    /// Does @b not close or free the underlying @c CassSession.
    ~SaltedBlobStore();

    SaltedBlobStore(const SaltedBlobStore&)            = delete;
    SaltedBlobStore& operator=(const SaltedBlobStore&) = delete;
    SaltedBlobStore(SaltedBlobStore&&)                 noexcept = delete;
    SaltedBlobStore& operator=(SaltedBlobStore&&)      noexcept = delete;

    /// @brief Creates the keyspace and table if they do not already exist,
    ///        then prepares the driver statements.
    ///
    /// Safe to call on an already-initialised cluster; the @c IF NOT EXISTS
    /// guards make it idempotent.  Blocks until all DDL statements have
    /// completed on the coordinator.
    ///
    /// @param replication_factor  SimpleStrategy replication factor (default 1).
    /// @throws std::runtime_error if any CQL statement fails.
    void create_schema(int replication_factor = 1);

    /// @brief Drops the entire keyspace (and all its tables) unconditionally.
    ///
    /// Also releases the prepared statements cached in this instance so the
    /// object can be reused against a freshly created schema.  Blocks until
    /// the DROP KEYSPACE completes.
    ///
    /// @throws std::runtime_error if the CQL statement fails.
    void drop_schema();

    /// @brief Writes a blob into the store, splitting and salting as needed.
    ///
    /// The blob is divided into @p chunk_size byte chunks.  Chunks are
    /// distributed round-robin across @c min(num_chunks, max_salt) salt
    /// values, each salt forming its own CQL partition.  Chunks belonging to
    /// the same partition are batched together up to @p max_batch_bytes before
    /// being sent, keeping individual batch payloads within server limits.
    ///
    /// At most @p max_concurrency batch futures are kept in-flight at once.
    /// A @c std::counting_semaphore is acquired before each submission; the
    /// completion callback releases it, so whichever future finishes first
    /// unblocks the producer immediately (true sliding window, no FIFO
    /// stalling).  Pass 0 (or @c kDefaultMaxConcurrency) to issue all batches
    /// at once without a cap.
    ///
    /// @note @p max_salt and @p chunk_size are per-call settings stored in
    ///       each row, so different keys in the same table may use different
    ///       layouts.
    ///
    /// @param key             Logical blob key; used as the CQL partition key component.
    /// @param blob            Raw bytes to store.
    /// @param max_salt        Maximum number of salt partitions to use.
    /// @param chunk_size      Maximum bytes per CQL row.
    /// @param max_batch_bytes Soft flush threshold for UNLOGGED batches (must be >= chunk_size).
    /// @param max_concurrency Max in-flight batch futures (0 = unlimited).
    /// @throws std::invalid_argument if any tuning parameter is out of range
    ///         (@p max_salt, @p chunk_size, @p max_batch_bytes, @p max_concurrency).
    /// @throws std::runtime_error    if any batch future returns a driver error.
    void write(std::span<const std::uint8_t> key,
               std::span<const std::uint8_t> blob,
               int         max_salt        = kDefaultMaxSalt,
               std::size_t chunk_size      = kDefaultChunkSize,
               std::size_t max_batch_bytes = kDefaultMaxBatchBytes,
               int         max_concurrency = kDefaultMaxConcurrency);

    /// @brief Returns the chunks of the blob stored under @p key, in order.
    ///
    /// Reads the sentinel row first to discover @c total_chunks and
    /// @c salt_cardinality, then issues one SELECT per salt partition.
    /// With @p max_concurrency == 0 all SELECTs are fired at once and awaited
    /// together; with @p max_concurrency > 0 a sliding window (semaphore +
    /// callback) limits the number of in-flight futures.  Chunks are placed
    /// directly into a pre-allocated @c vector<Bytes> indexed by @c chunk_id;
    /// no flat concatenation is performed so the caller avoids an extra copy.
    /// Use std::views::join to get a flat view if needed.
    ///
    /// @param key             Logical blob key to look up.
    /// @param max_concurrency Max in-flight SELECT futures (0 = unlimited).
    /// @return Ordered @c vector<Bytes> of chunks (one element per chunk_id),
    ///         or @c std::nullopt if @p key is unknown.
    /// @throws std::runtime_error if metadata is corrupt, a chunk is missing,
    ///         or a driver call fails.
    std::optional<std::vector<Bytes>> read(std::span<const std::uint8_t> key,
                                           int max_concurrency = kDefaultMaxConcurrency);

    /// @brief Deletes all rows associated with @p key.
    ///
    /// Reads the sentinel row to find the salt cardinality, then issues one
    /// DELETE per partition.  Non-sentinel partitions (@c salt != 0) are
    /// removed first; @c salt=0 (metadata) is deleted last so a failed erase
    /// can be retried.  If @p key is not found, returns silently without error.
    ///
    /// @param key             Logical blob key to delete.
    /// @param max_concurrency Max in-flight DELETE futures (0 = unlimited).
    /// @throws std::runtime_error if a driver call fails.
    void erase(std::span<const std::uint8_t> key,
               int max_concurrency = kDefaultMaxConcurrency);

    /// @brief Returns the storage layout of the blob stored under @p key.
    ///
    /// For each salt partition, reports the row count and total chunk bytes.
    /// Useful for diagnostics and understanding the salting distribution.
    /// With @p max_concurrency == 0 all partition SELECTs are fired at once;
    /// with @p max_concurrency > 0 a sliding window limits in-flight futures
    /// (same pattern as read).
    ///
    /// @param key             Logical blob key to inspect.
    /// @param max_concurrency Max in-flight SELECT futures (0 = unlimited).
    /// @return Layout description, or @c std::nullopt if @p key is unknown.
    /// @throws std::runtime_error if a driver call fails.
    std::optional<BlobLayout> describe(std::span<const std::uint8_t> key,
                                       int max_concurrency = kDefaultMaxConcurrency);

private:
    /// @brief Prepares all four CQL statements if not already prepared (idempotent).
    ///
    void prepare_();

    /// @brief Executes a single-parameter-free CQL statement synchronously.
    ///
    void execute_simple_(const std::string& cql);

    /// @brief Frees and nulls all cached CassPrepared handles.
    ///
    void release_prepared_();

    CassSession* session_;
    std::string  keyspace_;
    std::string  table_;

    const CassPrepared* p_insert_           = nullptr;  ///< INSERT INTO … VALUES (?,?,?,?,?,?)
    const CassPrepared* p_select_meta_      = nullptr;  ///< SELECT total_chunks, salt_cardinality … WHERE salt=0 AND chunk_id=0
    const CassPrepared* p_select_partition_ = nullptr;  ///< SELECT chunk_id, chunk … WHERE key=? AND salt=?
    const CassPrepared* p_delete_partition_ = nullptr;  ///< DELETE … WHERE key=? AND salt=?
};

}  // namespace scs
