package com.scylladb.springdemo_custom.common.conf

import com.datastax.oss.driver.api.core.CqlIdentifier
import com.datastax.oss.driver.api.core.cql.SimpleStatement
import com.datastax.oss.driver.api.querybuilder.SchemaBuilder
import com.datastax.oss.driver.api.core.type.DataTypes
import com.datastax.oss.driver.api.core.metadata.schema.ClusteringOrder
import com.datastax.oss.driver.api.core.CqlSession
import com.datastax.oss.driver.api.core.cql.PreparedStatement
import com.datastax.oss.driver.api.querybuilder.QueryBuilder
import com.datastax.oss.driver.api.querybuilder.relation.Relation
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Profile
import org.springframework.lang.NonNull

/**
 * A configuration class that exposes CQL statements for the stocks table as beans.
 *
 *
 * This component exposes a few [SimpleStatement]s that perform both DDL and DML operations
 * on the stocks table, as well as a few [PreparedStatement]s for common DML operations.
 */
@Configuration
@Profile("!unit-test")
class StockQueriesConfiguration {
    @Bean("stocks.simple.create")
    fun createTable(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return SchemaBuilder.createTable(keyspace, STOCKS)
            .ifNotExists()
            .withPartitionKey(SYMBOL, DataTypes.TEXT)
            .withClusteringColumn(DATE, DataTypes.TIMESTAMP)
            .withColumn(VALUE, DataTypes.DECIMAL)
            .withClusteringOrder(DATE, ClusteringOrder.DESC)
            .build()
    }

    @Bean("stocks.simple.drop")
    fun dropTable(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return SchemaBuilder.dropTable(keyspace, STOCKS).ifExists().build()
    }

    @Bean("stocks.simple.truncate")
    fun truncate(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.truncate(keyspace, STOCKS).build()
    }

    @Bean("stocks.simple.insert")
    fun insert(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.insertInto(keyspace, STOCKS)
            .value(SYMBOL, QueryBuilder.bindMarker(SYMBOL))
            .value(DATE, QueryBuilder.bindMarker(DATE))
            .value(VALUE, QueryBuilder.bindMarker(VALUE))
            .build()
    }

    @Bean("stocks.simple.deleteById")
    fun deleteById(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.deleteFrom(keyspace, STOCKS)
            .where(Relation.column(SYMBOL).isEqualTo(QueryBuilder.bindMarker(SYMBOL)))
            .where(Relation.column(DATE).isEqualTo(QueryBuilder.bindMarker(DATE)))
            .build()
    }

    @Bean("stocks.simple.findById")
    fun findById(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.selectFrom(keyspace, STOCKS)
            .columns(SYMBOL, DATE, VALUE)
            .where(Relation.column(SYMBOL).isEqualTo(QueryBuilder.bindMarker(SYMBOL)))
            .where(Relation.column(DATE).isEqualTo(QueryBuilder.bindMarker(DATE)))
            .build()
    }

    @Bean("stocks.simple.findBySymbol")
    fun findBySymbol(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.selectFrom(keyspace, STOCKS)
            .columns(SYMBOL, DATE, VALUE)
            .where(
                Relation.column(SYMBOL).isEqualTo(QueryBuilder.bindMarker(SYMBOL)),  // start inclusive
                Relation.column(DATE).isGreaterThanOrEqualTo(QueryBuilder.bindMarker(START)),  // end exclusive
                Relation.column(DATE).isLessThan(QueryBuilder.bindMarker(END))
            )
            .build()
    }

    @Bean("stocks.simple.findStockBySymbol")
    fun findStockBySymbol(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.selectFrom(keyspace, STOCKS)
            .columns(SYMBOL, DATE, VALUE)
            .where(
                Relation.column(SYMBOL).isEqualTo(QueryBuilder.bindMarker(SYMBOL))  // start inclusive
            )
            .build()
    }

    // a very ineffective way to do a full scan
    @Bean("stocks.simple.findAll")
    fun findAll(@NonNull keyspace: CqlIdentifier?): SimpleStatement {
        return QueryBuilder.selectFrom(keyspace, STOCKS)
            .columns(SYMBOL, DATE, VALUE)
            .build()
    }

    @Bean("stocks.prepared.insert")
    fun prepareInsert(
        session: CqlSession, @Qualifier("stocks.simple.insert") stockInsert: SimpleStatement?
    ): PreparedStatement {
        return session.prepare(stockInsert!!)
    }

    @Bean("stocks.prepared.deleteById")
    fun prepareDeleteById(
        session: CqlSession, @Qualifier("stocks.simple.deleteById") stockDeleteById: SimpleStatement?
    ): PreparedStatement {
        return session.prepare(stockDeleteById!!)
    }

    @Bean("stocks.prepared.findById")
    fun prepareFindById(
        session: CqlSession, @Qualifier("stocks.simple.findById") stockFindById: SimpleStatement?
    ): PreparedStatement {
        return session.prepare(stockFindById!!)
    }

    @Bean("stocks.prepared.findBySymbol")
    fun prepareFindBySymbol(
        session: CqlSession,
        @Qualifier("stocks.simple.findBySymbol") stockFindBySymbol: SimpleStatement?
    ): PreparedStatement {
        return session.prepare(stockFindBySymbol!!)
    }

    @Bean("stocks.prepared.findStockBySymbol")
    fun prepareFindStockBySymbol(
        session: CqlSession,
        @Qualifier("stocks.simple.findStockBySymbol") stockFindBySymbol: SimpleStatement?
    ): PreparedStatement {
        return session.prepare(stockFindBySymbol!!)
    }

    companion object {
        private val STOCKS = CqlIdentifier.fromCql("stocks")
        @JvmField
        val SYMBOL = CqlIdentifier.fromCql("symbol")
        @JvmField
        val DATE = CqlIdentifier.fromCql("date")
        @JvmField
        val VALUE = CqlIdentifier.fromCql("value")
        private val START = CqlIdentifier.fromCql("start")
        private val END = CqlIdentifier.fromCql("end")
    }
}