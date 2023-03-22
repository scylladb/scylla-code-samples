package com.scylladb.springdemo_custom.async.repository

import com.datastax.oss.driver.api.core.ConsistencyLevel
import com.datastax.oss.driver.api.core.CqlSession
import org.springframework.beans.factory.annotation.Qualifier
import com.scylladb.springdemo_custom.common.model.Stock
import java.util.concurrent.CompletionStage
import com.datastax.oss.driver.api.core.cql.AsyncResultSet
import com.datastax.oss.driver.api.core.cql.PreparedStatement
import com.datastax.oss.driver.api.core.cql.Row
import com.datastax.oss.driver.api.core.cql.SimpleStatement
import java.time.Instant
import org.springframework.context.annotation.Profile
import org.springframework.lang.NonNull
import org.springframework.stereotype.Repository
import java.util.*
import java.util.function.Function
import java.util.stream.Stream

/** A DAO that manages the persistence of [Stock] instances.  */
@Repository
@Profile("!unit-test")
class AsyncStockRepository(
    private val session: CqlSession,
    @param:Qualifier("stocks.prepared.insert") private val insert: PreparedStatement,
    @param:Qualifier("stocks.prepared.deleteById") private val deleteById: PreparedStatement,
    @param:Qualifier("stocks.prepared.findById") private val findById: PreparedStatement,
    @param:Qualifier("stocks.prepared.findBySymbol") private val findBySymbol: PreparedStatement,
    @param:Qualifier("stocks.prepared.findStockBySymbol") private val findStockBySymbol: PreparedStatement,
    @param:Qualifier("stocks.simple.findAll") private val findAll: SimpleStatement,
    private val rowMapper: Function<Row, Stock>
) {
    /**
     * Saves the given stock value.
     *
     * @param stock The stock value to save.
     * @return A future that will complete with the saved stock value.
     */
    @NonNull
    fun save(@NonNull stock: Stock): CompletionStage<Stock> {
        val bound = insert.bind(stock.symbol, stock.date, stock.value).setConsistencyLevel(ConsistencyLevel.LOCAL_QUORUM);
        val stage = session.executeAsync(bound)
        return stage.thenApply { _ -> stock }
    }

    /**
     * Deletes the stock value for the given symbol and date.
     *
     * @param symbol The stock symbol to delete.
     * @param date The stock date to delete.
     * @return A future that will complete when the operation is completed.
     */
    @NonNull
    fun deleteById(@NonNull symbol: String?, @NonNull date: Instant?): CompletionStage<Void?> {
        val bound = deleteById.bind(symbol, date)//.setConsistencyLevel(ConsistencyLevel.ALL);
        val stage = session.executeAsync(bound)
        return stage.thenApply { _ -> null }
    }

    /**
     * Retrieves the stock value uniquely identified by its symbol and date.
     *
     * @param symbol The stock symbol to find.
     * @param date The stock date to find.
     * @return A future that will complete with the retrieved stock value, or empty if not found.
     */
    @NonNull
    fun findById(@NonNull symbol: String?, @NonNull date: Instant?): CompletionStage<Optional<Stock>> {
        val bound = findById.bind(symbol, date)
        val stage = session.executeAsync(bound)
        return stage
            .thenApply { obj: AsyncResultSet -> obj.one() }
            .thenApply { value: Row? -> Optional.ofNullable(value) }
            .thenApply { optional: Optional<Row> ->
                optional.map(
                    rowMapper
                )
            }
    }

    /**
     * Retrieves all the stock values for a given symbol in a given date range, page by page.
     *
     * @param symbol The stock symbol to find.
     * @param start The date range start (inclusive).
     * @param end The date range end (exclusive).
     * @param offset The zero-based index of the first result to return.
     * @param limit The maximum number of results to return.
     * @return A future that will complete with a [Stream] of results.
     */
    @NonNull
    fun findAllBySymbol(
        @NonNull symbol: String?,
        @NonNull start: Instant?,
        @NonNull end: Instant?,
        offset: Long,
        limit: Long
    ): CompletionStage<Stream<Stock>> {
        val bound = findBySymbol.bind(symbol, start, end)
        val stage = session.executeAsync(bound)
        return stage
            .thenCompose(Function<AsyncResultSet, CompletionStage<List<Row>>> { first: AsyncResultSet? ->
                RowCollector(
                    first!!, offset, limit
                )
            })
            .thenApply { rows: List<Row> ->
                rows.stream().map(
                    rowMapper
                )
            }
    }

    /**
     * Retrieves all the stock values for a given symbol in a given date range, page by page.
     *
     * @param symbol The stock symbol to find.
     * @param start The date range start (inclusive).
     * @param end The date range end (exclusive).
     * @param offset The zero-based index of the first result to return.
     * @param limit The maximum number of results to return.
     * @return A future that will complete with a [Stream] of results.
     */
    @NonNull
    fun findStockBySymbol(
        @NonNull symbol: String?
    ): CompletionStage<Stream<Stock>> {
        val bound = findStockBySymbol.bind(symbol)
        val stage = session.executeAsync(bound)
        return stage
            .thenCompose(Function<AsyncResultSet, CompletionStage<List<Row>>> { first: AsyncResultSet? ->
                UnlimitedRowCollector(
                    first!!
                )
            })
            .thenApply { rows: List<Row> ->
                rows.stream().map(
                    rowMapper
                )
            }
    }

    /**
     * Retrieves all the stock values.
     *
     * a very ineffective way to do a full scan
     * @return A future that will complete with a [Stream] of results.
     */
    @NonNull
    fun findAll(): CompletionStage<Stream<Stock>> {
        val bound = findAll//.setConsistencyLevel(ConsistencyLevel.LOCAL_QUORUM);
        val stage = session.executeAsync(bound)
        return stage
            .thenCompose(Function<AsyncResultSet, CompletionStage<List<Row>>> { first ->
                UnlimitedRowCollector(
                    first!!
                )
            })
            .thenApply { rows: List<Row> ->
                rows.stream().map(
                    rowMapper
                )
            }
    }
}