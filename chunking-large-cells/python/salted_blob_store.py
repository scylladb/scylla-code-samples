"""
Modified salting technique for storing large blobs in ScyllaDB.

Each blob is split into fixed-size chunks. Chunks are distributed across
``salt_cardinality`` partitions per key by ``chunk_id % salt_cardinality``.
The sentinel row (``salt=0, chunk_id=0``) carries ``total_chunks`` and
``salt_cardinality`` so a reader can rebuild the blob without scanning
empty partitions.

Schema::

    CREATE TABLE <ks>.<t> (
        key blob,
        salt int,
        chunk_id int,
        chunk blob,
        total_chunks int,
        salt_cardinality int,
        PRIMARY KEY ((key, salt), chunk_id)
    );

``SaltedBlobStore.write`` accepts per-call tuning parameters (``max_salt``,
``chunk_size``, ``max_batch_bytes``, ``max_concurrency``) so different keys in
the same table may use different layouts.  Before issuing CQL, ``write``
validates:

* ``max_salt >= 1``
* ``chunk_size >= 1``
* ``max_batch_bytes >= chunk_size``
* ``max_concurrency >= 0`` (``0`` = unlimited in-flight futures)

The ``max_batch_bytes >= chunk_size`` rule ensures each UNLOGGED batch can
hold at least one full chunk.  Inserts within a salt partition are batched up
to ``max_batch_bytes`` (default 1 MiB, ``DEFAULT_MAX_BATCH_BYTES``) so the
server's ``batch_size_fail_threshold_in_kb`` is not tripped.

Reference: blog post "Storing large blobs in ScyllaDB".
"""
from __future__ import annotations

import functools
import threading
from dataclasses import dataclass
from typing import Callable, Iterable, Iterator, List, Optional, Tuple

from cassandra.cluster import ResponseFuture, ResultSet, Session          # type: ignore[import-untyped]
from cassandra.query import BatchStatement, BatchType, PreparedStatement  # type: ignore[import-untyped]


DEFAULT_CHUNK_SIZE = 4096
DEFAULT_MAX_SALT = 100
# UNLOGGED batches are bounded server-side (batch_size_fail_threshold_in_kb).
# Keep the per-batch payload comfortably below that limit.
DEFAULT_MAX_BATCH_BYTES = 1 * 1024 * 1024  # 1 MiB
# 0 = unlimited (fire all futures at once); >0 = true sliding-window cap.
DEFAULT_MAX_CONCURRENCY = 0


@dataclass
class _AsyncTask:
    """
    Submitter for a driver future plus an optional callback for its result.

    ``submit()`` is invoked once and must return the ``ResponseFuture``
    produced by ``Session.execute_async`` (single statement, batch, etc.).
    ``handle`` — when supplied — is called exactly once with the
    ``ResultSet`` returned by that future; write/delete tasks leave it
    unset because they only care about success/failure.
    """

    submit: Callable[[], ResponseFuture]
    handle: Optional[Callable[[ResultSet], None]] = None


@dataclass
class _Statements:
    insert: PreparedStatement
    select_meta: PreparedStatement
    select_partition: PreparedStatement
    delete_partition: PreparedStatement


@dataclass
class PartitionInfo:
    salt: int
    rows: int
    bytes: int


@dataclass
class BlobLayout:
    total_chunks: int
    salt_cardinality: int
    partitions: List[PartitionInfo]

    @property
    def total_bytes(self) -> int:
        return sum(p.bytes for p in self.partitions)


class SaltedBlobStore:
    """
    Read/write API on top of the salted-blob schema.
    """

    def __init__(self, session: Session, keyspace: str, table: str = "salted_blobs"):
        self.session = session
        self.keyspace = keyspace
        self.table = table
        self._stmts: Optional[_Statements] = None

    # ------------------------------------------------------------------ schema
    def create_schema(self, replication: Optional[dict] = None) -> None:
        replication = replication or {
            "class": "NetworkTopologyStrategy",
            "replication_factor": 1,
        }
        rep_str = ", ".join(
            f"'{k}': '{v}'" if isinstance(v, str) else f"'{k}': {v}"
            for k, v in replication.items()
        )
        self.session.execute(
            f"CREATE KEYSPACE IF NOT EXISTS {self.keyspace} "
            f"WITH replication = {{{rep_str}}}"
        )
        self.session.execute(
            f"CREATE TABLE IF NOT EXISTS {self.keyspace}.{self.table} ("
            f"  key blob,"
            f"  salt int,"
            f"  chunk_id int,"
            f"  chunk blob,"
            f"  total_chunks int,"
            f"  salt_cardinality int,"
            f"  PRIMARY KEY ((key, salt), chunk_id)"
            f")"
        )
        self._prepare()

    def drop_schema(self) -> None:
        self.session.execute(f"DROP KEYSPACE IF EXISTS {self.keyspace}")
        self._stmts = None

    def _prepare(self) -> None:
        if self._stmts is not None:
            return
        ks, t = self.keyspace, self.table
        self._stmts = _Statements(
            insert=self.session.prepare(
                f"INSERT INTO {ks}.{t} "
                f"(key, salt, chunk_id, chunk, total_chunks, salt_cardinality) "
                f"VALUES (?, ?, ?, ?, ?, ?)"
            ),
            select_meta=self.session.prepare(
                f"SELECT total_chunks, salt_cardinality FROM {ks}.{t} "
                f"WHERE key = ? AND salt = 0 AND chunk_id = 0"
            ),
            select_partition=self.session.prepare(
                f"SELECT chunk_id, chunk FROM {ks}.{t} WHERE key = ? AND salt = ?"
            ),
            delete_partition=self.session.prepare(
                f"DELETE FROM {ks}.{t} WHERE key = ? AND salt = ?"
            ),
        )

    def _fetch_meta(self, key: bytes) -> Optional[Tuple[int, int]]:
        """
        Return ``(total_chunks, salt_cardinality)`` from the sentinel row.

        Returns ``None`` if the sentinel row is missing.  Raises
        ``RuntimeError`` if the stored metadata is invalid (negative
        ``total_chunks`` or non-positive ``salt_cardinality``); centralising
        the check here means ``read``, ``delete``, and ``describe`` all
        reject corrupt metadata uniformly.
        """
        self._prepare()
        assert self._stmts is not None
        meta = self.session.execute(self._stmts.select_meta, (key,)).one()
        if meta is None:
            return None
        total_chunks, salt_cardinality = meta.total_chunks, meta.salt_cardinality
        if total_chunks < 0 or salt_cardinality <= 0:
            raise RuntimeError(
                f"invalid metadata: total_chunks={total_chunks}, "
                f"salt_cardinality={salt_cardinality}"
            )
        return total_chunks, salt_cardinality

    def _scan_partitions(
        self,
        key: bytes,
        salts: range,
        max_concurrency: int,
        on_rows: Callable[[int, ResultSet], None],
        *,
        op: str = "SELECT partition",
    ) -> None:
        """
        Run ``select_partition`` for each salt and invoke ``on_rows(salt, rows)``.
        """
        assert self._stmts is not None
        select = self._stmts.select_partition
        self._run_async_tasks(
            (
                _AsyncTask(
                    submit=functools.partial(
                        self.session.execute_async, select, (key, s)
                    ),
                    handle=functools.partial(on_rows, s),
                )
                for s in salts
            ),
            max_concurrency,
            op=op,
        )

    def _run_async_tasks(
        self,
        tasks: Iterable[_AsyncTask],
        max_concurrency: int,
        *,
        op: str,
    ) -> None:
        """
        Execute async tasks; optionally dispatch each future's result to ``handle``.
        """
        task_list = list(tasks)
        if not task_list:
            return

        if max_concurrency <= 0:
            futures = [(task, task.submit()) for task in task_list]
            for task, fut in futures:
                result = fut.result()
                if task.handle is not None:
                    task.handle(result)
            return

        slots = threading.Semaphore(max_concurrency)
        first_err: List[Exception] = []
        lock = threading.Lock()

        def _record_err(exc: BaseException) -> None:
            # Stash the first error; subsequent ones are dropped (the producer
            # only raises one) but the lock keeps the assignment race-free.
            with lock:
                if not first_err:
                    first_err.append(exc if isinstance(exc, Exception)
                                     else Exception(repr(exc)))

        def _on_done(result: ResultSet,
                     *,
                     handle: Optional[Callable[[ResultSet], None]]) -> None:
            # try/finally: slots.release() MUST run even if handle() raises;
            # otherwise the producer's drain loop would deadlock.  A raised
            # handler exception is captured so it propagates to the caller
            # instead of being swallowed by cassandra-driver's callback log.
            try:
                if handle is not None:
                    handle(result)
            except BaseException as exc:
                _record_err(exc)
            finally:
                slots.release()

        def _on_err(exc: Exception) -> None:
            # Same try/finally guarantee: even if _record_err itself raises
            # (e.g. allocation failure under memory pressure), the slot is
            # still released and the drain loop can complete.
            try:
                _record_err(exc)
            finally:
                slots.release()

        for task in task_list:
            slots.acquire()
            if first_err:
                slots.release()
                break
            task.submit().add_callbacks(
                callback=lambda result, h=task.handle: _on_done(result, handle=h),
                errback=_on_err,
            )

        for _ in range(max_concurrency):
            slots.acquire()
        if first_err:
            raise RuntimeError(f"{op}: {first_err[0]}")

    # ------------------------------------------------------------------- write
    def write(
        self,
        key: bytes,
        blob: bytes,
        max_salt: int = DEFAULT_MAX_SALT,
        chunk_size: int = DEFAULT_CHUNK_SIZE,
        max_batch_bytes: int = DEFAULT_MAX_BATCH_BYTES,
        max_concurrency: int = DEFAULT_MAX_CONCURRENCY,
    ) -> None:
        """
        Store ``blob`` under ``key``.

        ``max_salt`` and ``chunk_size`` may be chosen per-key without
        affecting any other key in the table.

        When ``max_concurrency > 0`` a true sliding window keeps exactly that
        many batch futures in-flight at once; 0 (default) fires all batches
        concurrently without a cap.

        Raises:
            ValueError: if any tuning parameter is out of range (see module
                docstring).
            RuntimeError: if a batch future fails.
        """
        if max_salt < 1:
            raise ValueError("max_salt must be >= 1")
        if chunk_size < 1:
            raise ValueError("chunk_size must be >= 1")
        if max_batch_bytes < 1:
            raise ValueError("max_batch_bytes must be >= 1")
        if max_concurrency < 0:
            raise ValueError("max_concurrency must be >= 0")
        if max_batch_bytes < chunk_size:
            raise ValueError("max_batch_bytes must be >= chunk_size")
        self._prepare()

        if not blob:
            # Empty blob: write a single sentinel row with total_chunks=0 so
            # read() can return [] without issuing any partition SELECTs.
            assert self._stmts is not None
            self.session.execute(
                self._stmts.insert,
                (key, 0, 0, b"", 0, 1),
            )
            return

        chunks = _split(blob, chunk_size)
        num_chunks = len(chunks)
        salt_cardinality = min(num_chunks, max_salt)

        groups: List[List[int]] = [[] for _ in range(salt_cardinality)]
        for chunk_id in range(num_chunks):
            groups[chunk_id % salt_cardinality].append(chunk_id)

        def _batch_tasks() -> Iterator[_AsyncTask]:
            for salt, chunk_ids in enumerate(groups):
                for batch in self._build_batches(
                    key, salt, chunk_ids, chunks,
                    num_chunks, salt_cardinality, max_batch_bytes,
                ):
                    yield _AsyncTask(
                        submit=functools.partial(self.session.execute_async, batch)
                    )

        self._run_async_tasks(_batch_tasks(), max_concurrency, op="INSERT batch")

    def _build_batches(
        self,
        key: bytes,
        salt: int,
        chunk_ids: List[int],
        chunks: List[bytes],
        total_chunks: int,
        salt_cardinality: int,
        max_batch_bytes: int,
    ) -> Iterator[BatchStatement]:
        assert self._stmts is not None
        stmt = self._stmts.insert
        batch = BatchStatement(batch_type=BatchType.UNLOGGED)
        batch_bytes = 0
        for cid in chunk_ids:
            data = chunks[cid]
            if batch_bytes and batch_bytes + len(data) > max_batch_bytes:
                yield batch
                batch = BatchStatement(batch_type=BatchType.UNLOGGED)
                batch_bytes = 0
            batch.add(stmt, (key, salt, cid, data, total_chunks, salt_cardinality))
            batch_bytes += len(data)
        if len(batch) > 0:
            yield batch

    # -------------------------------------------------------------------- read
    def read(
        self,
        key: bytes,
        max_concurrency: int = DEFAULT_MAX_CONCURRENCY,
    ) -> Optional[List[bytes]]:
        """
        Return the chunks of the blob stored under ``key`` (or ``None``).

        Returns the raw list of chunks in order rather than assembling them
        into a single buffer — mirrors the C++ ``vector<Bytes>`` return that
        avoids the final concatenation copy. Use itertools.chain.from_iterable
        to create a flat view of the chunks.

        Returns an empty list immediately when the stored blob was empty
        (``total_chunks == 0``).

        When ``max_concurrency > 0`` a true sliding window keeps exactly that
        many partition SELECT futures in-flight at once; 0 (default) fires all
        partition SELECTs concurrently without a cap.

        Raises:
            RuntimeError: if the stored metadata is invalid, a chunk row has
                an out-of-range ``chunk_id`` or an empty payload, or a chunk
                is missing.
        """
        meta = self._fetch_meta(key)
        if meta is None:
            return None
        total_chunks, salt_cardinality = meta

        if total_chunks == 0:
            return []

        # Empty bytes b"" is the "not yet filled" sentinel.  Since
        # write() handles empty blobs via the total_chunks=0 path above,
        # every chunk of a non-empty blob is guaranteed non-empty — the
        # _collect callback enforces this invariant on every incoming row.
        chunks: List[bytes] = [b""] * total_chunks

        def _collect(_salt: int, rows: ResultSet) -> None:
            for row in rows:
                cid = row.chunk_id
                data = row.chunk
                if cid < 0 or cid >= total_chunks:
                    raise RuntimeError(
                        f"chunk_id {cid} out of range "
                        f"(total_chunks={total_chunks})"
                    )
                if not data:
                    raise RuntimeError(
                        f"chunk_id {cid}: corrupt chunk row (empty payload)"
                    )
                chunks[cid] = data

        self._scan_partitions(
            key,
            range(salt_cardinality),
            max_concurrency,
            _collect,
        )

        try:
            first_missing = next(i for i, c in enumerate(chunks) if not c)
        except StopIteration:
            return chunks
        raise RuntimeError(
            f"key={key!r}: missing chunk_id {first_missing} "
            f"(total_chunks={total_chunks})"
        )

    # ------------------------------------------------------------------ delete
    def delete(
        self,
        key: bytes,
        max_concurrency: int = DEFAULT_MAX_CONCURRENCY,
    ) -> None:
        """
        Delete all rows for ``key``.

        Non-sentinel partitions (``salt != 0``) are removed first; the sentinel
        partition (``salt=0``, carrying ``total_chunks`` / ``salt_cardinality``)
        is deleted last so a failed delete can be retried.
        """
        meta = self._fetch_meta(key)
        if meta is None:
            return
        total_chunks, salt_cardinality = meta

        assert self._stmts is not None
        delete = self._stmts.delete_partition

        def _delete_tasks(salts: Iterable[int]) -> Iterator[_AsyncTask]:
            for s in salts:
                yield _AsyncTask(
                    submit=functools.partial(
                        self.session.execute_async, delete, (key, s)
                    )
                )

        self._run_async_tasks(
            _delete_tasks(range(1, salt_cardinality)),
            max_concurrency,
            op="DELETE partition",
        )
        self._run_async_tasks(
            _delete_tasks([0]),
            max_concurrency,
            op="DELETE partition",
        )

    # ----------------------------------------------------------------- inspect
    def describe(
        self,
        key: bytes,
        max_concurrency: int = DEFAULT_MAX_CONCURRENCY,
    ) -> Optional[BlobLayout]:
        """
        Return how a key is laid out across salted partitions.

        When ``max_concurrency > 0`` a true sliding window keeps exactly that
        many partition SELECT futures in-flight at once; 0 (default) fires all
        partition SELECTs concurrently without a cap.
        """
        meta = self._fetch_meta(key)
        if meta is None:
            return None
        total_chunks, salt_cardinality = meta
        layout = BlobLayout(
            total_chunks=total_chunks,
            salt_cardinality=salt_cardinality,
            partitions=[
                PartitionInfo(salt=s, rows=0, bytes=0) for s in range(salt_cardinality)
            ],
        )

        def _fill(salt: int, rows: ResultSet) -> None:
            row_list = list(rows)
            layout.partitions[salt] = PartitionInfo(
                salt=salt,
                rows=len(row_list),
                bytes=sum(len(r.chunk) for r in row_list),
            )

        self._scan_partitions(
            key,
            range(salt_cardinality),
            max_concurrency,
            _fill,
            op="SELECT partition (describe)",
        )
        return layout


def _split(blob: bytes, chunk_size: int) -> List[bytes]:
    return [blob[i:i + chunk_size] for i in range(0, len(blob), chunk_size)]


__all__ = [
    "BlobLayout",
    "PartitionInfo",
    "SaltedBlobStore",
    "DEFAULT_CHUNK_SIZE",
    "DEFAULT_MAX_SALT",
    "DEFAULT_MAX_BATCH_BYTES",
    "DEFAULT_MAX_CONCURRENCY",
]
