package com.scylladb.model

import org.springframework.data.cassandra.core.mapping.PrimaryKey
import org.springframework.data.cassandra.core.mapping.Table
import java.util.UUID

@Table
class Monster {
    @PrimaryKey
    var id: UUID? = null
    var name: String? = null
    var description: String? = null
    var isalive = false

    constructor(id: UUID?, name: String?, description: String?, isalive: Boolean) {
        this.id = id
        this.name = name
        this.description = description
        this.isalive = isalive
    }

    override fun toString(): String {
        return "Monster [id=" + id + ", name=" + name + ", desc=" + description + ", isalive=" + isalive + "]"
    }
}