import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
	id("org.springframework.boot") version "2.6.0" //if you upgrade this, verify below scylla driver or comment it out to be safe
	id("io.spring.dependency-management") version "1.0.11.RELEASE"
	kotlin("jvm") version "1.6.0"
	kotlin("plugin.spring") version "1.6.0"
}

group = "com.scylladb"
version = "0.0.1-SNAPSHOT"
java.sourceCompatibility = JavaVersion.VERSION_11

repositories {
	mavenCentral()
	mavenLocal()
}

dependencies {
	implementation("com.scylladb:java-driver-core:4.13.0.0")
	implementation("com.scylladb:java-driver-query-builder:4.13.0.0")
	// 3.2.7 has 4.11 driver, 3.3.0 has 4.13 driver !!!
	// since 2.6.0 spring boot uses 3.3.0 spring-data-cassandra
	implementation("org.springframework.boot:spring-boot-starter-data-cassandra")
	implementation("org.springframework.boot:spring-boot-starter-web")
	implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
	implementation("org.jetbrains.kotlin:kotlin-reflect")
	implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
	testImplementation("org.springframework.boot:spring-boot-starter-test")
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
