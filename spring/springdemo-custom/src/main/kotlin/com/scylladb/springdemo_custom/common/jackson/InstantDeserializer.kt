package com.scylladb.springdemo_custom.common.jackson

import com.scylladb.springdemo_custom.common.convert.StringToInstantConverter
import com.fasterxml.jackson.core.JsonParseException
import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.deser.std.StdScalarDeserializer
import org.springframework.core.convert.converter.Converter
import java.lang.Exception
import org.springframework.boot.jackson.JsonComponent
import java.time.Instant
import kotlin.Throws
import java.io.IOException



/**
 * A deserializer used to deserialize [Instant] instances using a compact format: `yyyyMMddHHmmssSSS`, always expressed in UTC.
 *
 * @see StringToInstantConverter
 */
@JsonComponent
class InstantDeserializer(converter: Converter<String, Instant>) : StdScalarDeserializer<Instant>(
    Instant::class.java
) {
    private val converter: Converter<String, Instant>
    @Throws(IOException::class)
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): Instant? {
        return try {
            val text = p.readValueAs(String::class.java)
            if (text == null) null else converter.convert(text)
        } catch (e: Exception) {
            throw JsonParseException(p, "Could not parse node as instant", e)
        }
    }

    init {
        this.converter = converter
    }
}