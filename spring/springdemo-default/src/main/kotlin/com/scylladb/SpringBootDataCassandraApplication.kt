package com.scylladb

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class SpringdemoDefaultApplication

fun main(args: Array<String>) {
    runApplication<SpringdemoDefaultApplication>(*args)
}
