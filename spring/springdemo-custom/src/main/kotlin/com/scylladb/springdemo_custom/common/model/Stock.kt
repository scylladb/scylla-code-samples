package com.scylladb.springdemo_custom.common.model

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.time.Instant
import java.math.BigDecimal
import org.springframework.lang.NonNull
import java.util.*

/**
 * The value of a stock described by its symbol, at a given point in time.
 *
 *
 * This POJO models the database table `stocks`.
 */
class Stock @JsonCreator constructor(
    /**
     * Returns the stock symbol. The stock symbol is the table's the partition key.
     *
     * @return The stock symbol.
     */
    @get:NonNull
    @param:NonNull @param:JsonProperty("symbol") val symbol: String,
    /**
     * Returns the instant when the stock value was recorded. This value is the table's clustering
     * column.
     *
     * @return The instant when the stock value was recorded.
     */
    @get:NonNull
    @param:NonNull @param:JsonProperty("date") val date: Instant,
    /**
     * Returns the stock value. This is a regular column in the table.
     *
     * @return The stock value.
     */
    @get:NonNull
    @param:NonNull @param:JsonProperty("value") val value: BigDecimal
) {

    override fun equals(other: Any?): Boolean {
        if (this === other) {
            return true
        }
        if (other !is Stock) {
            return false
        }
        val that = other
        return symbol == that.symbol && date == that.date && value == that.value
    }

    override fun hashCode(): Int {
        return Objects.hash(symbol, date, value)
    }

    override fun toString(): String {
        return "$symbol at $date = $value"
    }
}