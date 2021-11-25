package com.scylladb.springdemo_custom.async.repository

import com.datastax.oss.driver.api.core.cql.AsyncResultSet
import com.datastax.oss.driver.api.core.cql.Row
import java.util.ArrayList
import java.util.concurrent.CompletableFuture

class RowCollector internal constructor(first: AsyncResultSet, var offset: Long, var limit: Long) :
    CompletableFuture<List<Row>>() {
    val rows: MutableList<Row> = ArrayList()
    fun consumePage(page: AsyncResultSet) {
        for (row in page.currentPage()) {
            if (offset > 0) {
                offset--
            } else if (limit > 0) {
                rows.add(row)
                limit--
            }
        }
        if (page.hasMorePages() && limit > 0) {
            page.fetchNextPage().thenAccept { nextPage: AsyncResultSet -> consumePage(nextPage) }
        } else {
            complete(rows)
        }
    }

    init {
        consumePage(first)
    }
}