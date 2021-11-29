package com.scylladb.springdemo_custom.common.jackson

import com.fasterxml.jackson.core.JsonGenerationException
import com.fasterxml.jackson.core.JsonGenerator
import org.springframework.boot.jackson.JsonComponent
import java.time.Instant
import com.fasterxml.jackson.databind.ser.std.StdSerializer
import kotlin.Throws
import java.io.IOException
import com.fasterxml.jackson.databind.SerializerProvider
import org.springframework.core.convert.converter.Converter
import java.lang.Exception

/**
 * A serializer used to serialize [Instant] instances using a compact format: `yyyyMMddHHmmssSSS`, always expressed in UTC.
 *
 * @see InstantToStringConverter
 */
@JsonComponent
class InstantSerializer(private val converter: Converter<Instant, String>) : StdSerializer<Instant>(
    Instant::class.java
) {
    @Throws(IOException::class)
    override fun serialize(instant: Instant?, gen: JsonGenerator, serializerProvider: SerializerProvider) {
        try {
            if (instant == null) {
                gen.writeNull()
            } else {
                gen.writeString(converter.convert(instant))
            }
        } catch (e: Exception) {
            throw JsonGenerationException("Could not serialize instant: $instant", e, gen)
        }
    }
}