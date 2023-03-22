package com.scylladb.springdemo_custom.common.controller

import java.time.Instant
import com.scylladb.springdemo_custom.common.model.Stock
//import jakarta.servlet.http.HttpServletRequest
import javax.servlet.http.HttpServletRequest
import org.springframework.core.convert.converter.Converter
import org.springframework.lang.NonNull
import org.springframework.stereotype.Component
import org.springframework.web.servlet.support.ServletUriComponentsBuilder
import java.net.URI

/** A helper class that creates URIs for controllers dealing with [Stock] objects.  */
@Component
class StockUriHelper(private val instantStringConverter: Converter<Instant, String>) {
    /**
     * Creates an URI pointing to a specific stock value.
     *
     * @param request The HTTP request that will serve as the base for new URI.
     * @param stock The stock value to create an URI for.
     * @return An URI pointing to a specific stock value.
     */
    @NonNull
    fun buildDetailsUri(@NonNull request: HttpServletRequest?, @NonNull stock: Stock): URI {
        val date = instantStringConverter.convert(stock.date)
        return ServletUriComponentsBuilder.fromRequestUri(request!!)
            .replacePath("/api/v1/stocks/{symbol}/{date}")
            .buildAndExpand(stock.symbol, date)
            .toUri()
    }
}