package com.scylladb.springdemo_custom.async.repository

import com.datastax.oss.driver.api.core.cql.AsyncResultSet
import com.datastax.oss.driver.api.core.cql.Row
import java.util.ArrayList
import java.util.concurrent.CompletableFuture

class UnlimitedRowCollector internal constructor(first: AsyncResultSet) :
    CompletableFuture<List<Row>>() {
    val rows: MutableList<Row> = ArrayList()
    fun consumePage(page: AsyncResultSet) {
        for (row in page.currentPage()) {
                rows.add(row)
        }
        if (page.hasMorePages()) {
            page.fetchNextPage().thenAccept { nextPage: AsyncResultSet -> consumePage(nextPage) }
        } else {
            complete(rows)
        }
    }

    init {
        consumePage(first)
    }
}