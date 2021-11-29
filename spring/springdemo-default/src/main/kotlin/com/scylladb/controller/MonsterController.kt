package com.scylladb.controller

import org.springframework.web.bind.annotation.CrossOrigin
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.beans.factory.annotation.Autowired
import com.scylladb.repository.MonsterRepository
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.http.ResponseEntity
import com.scylladb.model.Monster
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PathVariable
import java.util.UUID
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import com.datastax.oss.driver.api.core.uuid.Uuids
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.DeleteMapping
import java.lang.Exception
import java.util.ArrayList

@CrossOrigin(origins = ["http://localhost:8081"])
@RestController
@RequestMapping("/api")
class MonsterController {
    @Autowired
    var monsterRepository: MonsterRepository? = null
    @GetMapping("/monsters")
    fun getAllMonsters(@RequestParam(required = false) name: String?): ResponseEntity<List<Monster>?> {
        return try {
            val monsters: MutableList<Monster> = ArrayList()
            if (name == null) monsterRepository!!.findAll()
                .forEach { e -> monsters.add(e!!) }
            else monsterRepository!!.findByNameContaining(name)!!
                .forEach { e -> monsters.add(e!!) }
            if (monsters.isEmpty()) {
                ResponseEntity(HttpStatus.NO_CONTENT)
            } else ResponseEntity(monsters, HttpStatus.OK)
        } catch (e: Exception) {
            ResponseEntity(null, HttpStatus.INTERNAL_SERVER_ERROR)
        }
    }

    @GetMapping("/monsters/{id}")
    fun getMonsterById(@PathVariable("id") id: UUID): ResponseEntity<Monster> {
        val monsterData = monsterRepository!!.findById(id)
        return if (monsterData.isPresent) {
            ResponseEntity(monsterData.get(), HttpStatus.OK)
        } else {
            ResponseEntity(HttpStatus.NOT_FOUND)
        }
    }

    @PostMapping("/monsters")
    fun createMonster(@RequestBody monster: Monster): ResponseEntity<Monster> {
        return try {
            val _monster =
                monsterRepository!!.save(Monster(Uuids.timeBased(), monster.name, monster.description, false))
            ResponseEntity(_monster, HttpStatus.CREATED)
        } catch (e: Exception) {
            ResponseEntity(null , HttpStatus.INTERNAL_SERVER_ERROR)
        }
    }

    @PutMapping("/monsters/{id}")
    fun updateMonster(@PathVariable("id") id: UUID, @RequestBody monster: Monster): ResponseEntity<Monster> {
        val monsterData = monsterRepository!!.findById(id)
        return if (monsterData.isPresent) {
            val _monster = monsterData.get()
            _monster.name = monster.name
            _monster.description = monster.description
            _monster.isalive = monster.isalive
            ResponseEntity(monsterRepository!!.save(_monster), HttpStatus.OK)
        } else {
            ResponseEntity(HttpStatus.NOT_FOUND)
        }
    }

    @DeleteMapping("/monsters/{id}")
    fun deleteMonster(@PathVariable("id") id: UUID): ResponseEntity<HttpStatus> {
        return try {
            monsterRepository!!.deleteById(id)
            ResponseEntity(HttpStatus.NO_CONTENT)
        } catch (e: Exception) {
            ResponseEntity(HttpStatus.INTERNAL_SERVER_ERROR)
        }
    }

    @DeleteMapping("/monsters")
    fun deleteAllMonsters(): ResponseEntity<HttpStatus> {
        return try {
            monsterRepository!!.deleteAll()
            ResponseEntity(HttpStatus.NO_CONTENT)
        } catch (e: Exception) {
            ResponseEntity(HttpStatus.INTERNAL_SERVER_ERROR)
        }
    }

    @GetMapping("/monsters/isalive")
    fun findByAlive(): ResponseEntity<List<Monster?>?> {
        return try {
            val monsters = monsterRepository!!.findByIsalive(true)
            if (monsters!!.isEmpty()) {
                ResponseEntity(HttpStatus.NO_CONTENT)
            } else ResponseEntity(monsters, HttpStatus.OK)
        } catch (e: Exception) {
            ResponseEntity(HttpStatus.INTERNAL_SERVER_ERROR)
        }
    }
}