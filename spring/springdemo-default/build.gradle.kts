import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
	id("org.springframework.boot") version "2.6.0" // don't go below 2.5.0, your queries won't be prepared with default CassandraRepository!!!
	//if you upgrade from 2.6.0, verify below scylla driver or comment it out to be safe
	id("io.spring.dependency-management") version "1.0.11.RELEASE"
	kotlin("jvm") version "1.6.0"
	kotlin("plugin.spring") version "1.6.0"
}

group = "com.scylladb"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_11

repositories {
	mavenCentral()
}

dependencies {
//	implementation("com.scylladb:java-driver-core:4.13.0.0")
//	implementation("com.scylladb:java-driver-query-builder:4.13.0.0")
	// 3.2.7 has 4.11 driver, 3.3.0 has 4.13 driver !!!
	// since 2.6.0 spring boot uses 3.3.0 spring-data-cassandra
	implementation("org.springframework.boot:spring-boot-starter-data-cassandra")
	implementation("org.springframework.boot:spring-boot-starter-web")
	implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
	implementation("io.projectreactor.kotlin:reactor-kotlin-extensions")
	implementation("org.jetbrains.kotlin:kotlin-reflect")
	implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
	implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")
	testImplementation("org.springframework.boot:spring-boot-starter-test")
	testImplementation("io.projectreactor:reactor-test")
}

tasks.withType<KotlinCompile> {
	kotlinOptions {
		freeCompilerArgs = listOf("-Xjsr305=strict")
		jvmTarget = "11"
	}
}

tasks.withType<Test> {
	useJUnitPlatform()
}
