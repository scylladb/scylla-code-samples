package com.scylladb.springdemo_custom.async.controller

import com.datastax.oss.driver.api.core.DriverException
import com.scylladb.springdemo_custom.async.repository.AsyncStockRepository
import com.scylladb.springdemo_custom.common.controller.StockUriHelper
import com.scylladb.springdemo_custom.common.model.Stock
//import jakarta.servlet.http.HttpServletRequest
import javax.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.lang.NonNull
import org.springframework.web.bind.annotation.*
import java.time.Instant
import java.util.*
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.stream.Stream

/** A REST controller that performs CRUD actions on [Stock] instances.  */
@CrossOrigin(origins = ["http://localhost:8082"])
@RestController
@RequestMapping("/api/v1")
class AsyncStockController(private val stockRepository: AsyncStockRepository, private val uriHelper: StockUriHelper) {
    /**
     * Creates a new stock value (POST method).
     *
     * @param stock The stock value to create.
     * @param request The current HTTP request.
     * @return The created stocked value.
     */
    @PostMapping("/stocks")
    fun createStock(
        @RequestBody stock: Stock?, @NonNull request: HttpServletRequest?
    ): CompletionStage<ResponseEntity<Stock?>> {
        return stockRepository
            .save(stock!!)
            .thenApply { created: Stock? ->
                val location = uriHelper.buildDetailsUri(request!!, created!!)
                ResponseEntity.created(location).body(created)
            }
    }

    /**
     * Updates the stock value at the given path (PUT method).
     *
     * @param symbol The stock symbol to update.
     * @param date The stock date to update.
     * @param stock The new stock value.
     * @return The updated stock value.
     */
    @PutMapping("/stocks/{symbol}/{date}")
    fun updateStock(
        @PathVariable("symbol") symbol: String?,
        @PathVariable("date") date: Instant?,
        @RequestBody stock: Stock
    ): CompletionStage<ResponseEntity<Stock>> {
        val future = CompletableFuture<ResponseEntity<Stock>>()
        stockRepository
            .findById(symbol!!, date!!)
            .whenComplete { maybeFound: Optional<Stock>, error1: Throwable? ->
                if (error1 == null) {
                    maybeFound
                        .map { found: Stock -> Stock(found.symbol, found.date, stock.value) }
                        .ifPresentOrElse(
                            { toUpdate: Stock? ->
                                stockRepository
                                    .save(toUpdate!!)
                                    .whenComplete { found: Stock?, error2: Throwable? ->
                                        if (error2 == null) {
                                            future.complete(ResponseEntity.ok(found))
                                        } else {
                                            future.completeExceptionally(error2)
                                        }
                                    }
                            }
                        ) { future.complete(ResponseEntity.notFound().build()) }
                } else {
                    future.completeExceptionally(error1)
                }
            }
        return future
    }

    /**
     * Deletes a stock value (DELETE method).
     *
     * @param symbol The stock symbol to delete.
     * @param date The stock date to delete.
     * @return An empty response.
     */
    @DeleteMapping("/stocks/{symbol}/{date}")
    fun deleteStock(
        @PathVariable("symbol") symbol: String?, @PathVariable("date") date: Instant?
    ): CompletionStage<ResponseEntity<Void?>> {
        return stockRepository.deleteById(symbol!!, date!!).thenApply { _ -> ResponseEntity.ok().build() }
    }

    /**
     * Retrieves the stock value for the given symbol and date (GET method).
     *
     * @param symbol The stock symbol to find.
     * @param date The stock date to find.
     * @return The found stock value, or empty if no stock value was found.
     */
    @GetMapping("/stocks/{symbol}/{date}")
    fun findStock(
        @PathVariable("symbol") symbol: String?, @PathVariable("date") date: Instant?
    ): CompletionStage<ResponseEntity<Stock>> {
        return stockRepository
            .findById(symbol!!, date!!)
            .thenApply { stock ->
                stock.map { body: Stock -> ResponseEntity.ok(body) }
                    .orElse(ResponseEntity.notFound().build())
            }
    }

    /**
     * Lists the available stocks for the given symbol and date range (GET method).
     *
     * @param symbol The symbol to list stocks for.
     * @param offset The zero-based index of the first result to return.
     * @param limit The maximum number of results to return.
     * @return The available stocks for the given symbol and date range.
     */
    @GetMapping("/stocks/{symbol}")
    fun listStock(
        @PathVariable(name = "symbol") @NonNull symbol: String?
    ): CompletionStage<Stream<Stock>> {
        return stockRepository.findStockBySymbol(symbol!!)
    }

    /**
     * Lists the available stocks.
     *
     * @return The available stocks
     */
    @GetMapping("/stocks")
    fun listStocks(): CompletionStage<Stream<Stock>> {
        return stockRepository.findAll()
    }

    /**
     * Converts [DriverException]s into HTTP 500 error codes and outputs the error message as
     * the response body.
     *
     * @param e The [DriverException].
     * @return The error message to be used as response body.
     */
    @ExceptionHandler(Exception::class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    fun errorHandler(e: DriverException): String? {
        return e.message
    }
}