package com.scylladb.repository

import org.springframework.data.cassandra.repository.CassandraRepository
import com.scylladb.model.Monster
import java.util.UUID
import org.springframework.data.cassandra.repository.AllowFiltering

interface MonsterRepository : CassandraRepository<Monster?, UUID?> {
    @AllowFiltering
    fun findByIsalive(isalive: Boolean): List<Monster?>?
    fun findByNameContaining(name: String?): List<Monster?>?
}