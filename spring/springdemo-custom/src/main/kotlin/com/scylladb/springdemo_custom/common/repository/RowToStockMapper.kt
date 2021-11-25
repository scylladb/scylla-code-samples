package com.scylladb.springdemo_custom.common.repository

import com.datastax.oss.driver.api.core.cql.Row
import com.scylladb.springdemo_custom.common.model.Stock
import com.scylladb.springdemo_custom.common.conf.StockQueriesConfiguration
import org.springframework.stereotype.Component
import java.util.*
import java.util.function.Function

/**
 * A row mapping function that creates a [Stock] instance from a database [Row].
 *
 *
 * The row is expected to contain all 3 columns in the `stocks` table: `symbol
` * , `date` and `value`, as if it were obtained by a CQL query such as
 * `SELECT symbol, date, value FROM stocks WHERE ...`.
 */
@Component
class RowToStockMapper : Function<Row, Stock> {
    override fun apply(row: Row): Stock {
        val symbol =
            Objects.requireNonNull(row.getString(StockQueriesConfiguration.SYMBOL), "column symbol cannot be null")
        val date = Objects.requireNonNull(row.getInstant(StockQueriesConfiguration.DATE), "column date cannot be null")
        val value =
            Objects.requireNonNull(row.getBigDecimal(StockQueriesConfiguration.VALUE), "column value cannot be null")
        return Stock(symbol!!, date!!, value!!)
    }
}