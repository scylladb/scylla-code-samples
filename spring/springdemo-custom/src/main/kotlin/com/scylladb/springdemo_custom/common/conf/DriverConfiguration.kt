package com.scylladb.springdemo_custom.common.conf

import com.datastax.oss.driver.api.core.CqlIdentifier
import com.datastax.oss.driver.api.core.config.ProgrammaticDriverConfigLoaderBuilder
import com.datastax.oss.driver.api.core.config.DriverConfigLoader
import com.datastax.oss.driver.api.core.config.DefaultDriverOption
import com.datastax.oss.driver.internal.core.auth.PlainTextAuthProvider
import com.datastax.oss.driver.api.core.CqlSessionBuilder
import java.net.InetSocketAddress
import org.springframework.beans.factory.annotation.Qualifier
import com.datastax.oss.driver.api.core.CqlSession
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Profile
import org.springframework.lang.NonNull
import org.springframework.util.StringUtils

/**
 * The driver configuration.
 *
 *
 * Driver options should be specified in the usual way, that is, through an `
 * application.conf` file accessible on the application classpath or through `application.properties`.
 * See the [driver](https://java-driver.docs.scylladb.com/stable/) section in the online docs for more information.
 *
 *
 * To illustrate how to integrate the driver configuration with Spring, a few driver options
 * should be configured through Spring's own configuration mechanism:
 *
 *
 *  1. `driver.contactPoints`: this property will override the driver's `datastax-java-driver.basic.contact-points` option; it will default to `127.0.0.1
` *  if unspecified;
 *  1. `driver.port`: this property will be combined with the previous one to create
 * initial contact points; it will default to `9042` if unspecified;
 *  1. `driver.localdc`: this property will override the driver's `datastax-java-driver.basic.load-balancing-policy.local-datacenter` option; it has no
 * default value and must be specified;
 *  1. `driver.keyspace`: this property will override the driver's `datastax-java-driver.basic.session-keyspace` option; it has no default value and must be
 * specified;
 *  1. `driver.consistency`: this property will override the driver's `datastax-java-driver.basic.request.consistency`; it will default to `LOCAL_QUORUM
` *  if unspecified;
 *  1. `driver.pageSize`: this property will override the driver's `datastax-java-driver.basic.request.page-size`; it will default to `10` if
 * unspecified;
 *  1. `driver.username`: this property will override the driver's `datastax-java-driver.advanced.auth-provider.username` option; if unspecified, it will be
 * assumed that no authentication is required;
 *  1. `driver.password`: this property will override the driver's `datastax-java-driver.advanced.auth-provider.password` option; if unspecified, it will be
 * assumed that no authentication is required;
 *
 *
 * The above properties should be typically declared in an `application.yml` file.
 */
//if you comment out below, then your application.properties has to be properly set up
@Configuration
@Profile("!unit-test & !integration-test")
class DriverConfiguration {
    @Value("#{'\${driver.contactPoints}'.split(',')}")
    protected var contactPoints: List<String>? = null

    @Value("\${driver.port:9042}")
    protected var port = 0

    @Value("\${driver.localdc}")
    protected var localDc: String? = null

    @Value("\${driver.keyspace}")
    protected var keyspaceName: String? = null

    @Value("\${driver.consistency:LOCAL_QUORUM}")
    protected var consistency: String? = null

    @Value("\${driver.username}")
    protected var username: String? = null

    @Value("\${driver.password}")
    protected var password: String? = null

    /**
     * Returns the keyspace to connect to. The keyspace specified here must exist.
     *
     * @return The [keyspace][CqlIdentifier] bean.
     */
    @Bean
    fun keyspace(): CqlIdentifier {
        return CqlIdentifier.fromCql(keyspaceName!!)
    }

    /**
     * Returns a [ProgrammaticDriverConfigLoaderBuilder] to load driver options.
     *
     *
     * Use this loader if you need to programmatically override default values for any driver
     * setting. In this example, we manually set the default consistency level to use, and, if a
     * username and password are present, we define a basic authentication scheme using [ ].
     *
     *
     * Any value explicitly set through this loader will take precedence over values found in the
     * driver's standard application.conf file.
     *
     * @return The [ProgrammaticDriverConfigLoaderBuilder] bean.
     */
    @Bean
    fun configLoaderBuilder(): ProgrammaticDriverConfigLoaderBuilder {
        var configLoaderBuilder = DriverConfigLoader.programmaticBuilder()
            .withString(DefaultDriverOption.REQUEST_CONSISTENCY, consistency!!)
        if (StringUtils.hasLength(username) && StringUtils.hasLength(password)) {
            configLoaderBuilder = configLoaderBuilder
                .withString(
                    DefaultDriverOption.AUTH_PROVIDER_CLASS, PlainTextAuthProvider::class.java.name
                )
                .withString(DefaultDriverOption.AUTH_PROVIDER_USER_NAME, username!!)
                .withString(DefaultDriverOption.AUTH_PROVIDER_PASSWORD, password!!)
        }
        return configLoaderBuilder
    }

    /**
     * Returns a [CqlSessionBuilder] that will configure sessions using the provided [ ], as well as the contact points and
     * local datacenter name found in application.yml, merged with other options found in
     * application.conf.
     *
     * @param driverConfigLoaderBuilder The [ProgrammaticDriverConfigLoaderBuilder] bean to use.
     * @return The [CqlSessionBuilder] bean.
     */
    @Bean
    fun sessionBuilder(
        @NonNull driverConfigLoaderBuilder: ProgrammaticDriverConfigLoaderBuilder
    ): CqlSessionBuilder {
        var sessionBuilder = CqlSessionBuilder().withConfigLoader(driverConfigLoaderBuilder.build())
        for (contactPoint in contactPoints!!) {
            val address = InetSocketAddress.createUnresolved(contactPoint, port)
            sessionBuilder = sessionBuilder.addContactPoint(address)
        }
        return sessionBuilder.withLocalDatacenter(localDc!!)
    }

    /**
     * Returns the [CqlSession] to use, configured with the provided [ session builder][CqlSessionBuilder]. The returned session will be automatically connected to the given keyspace.
     *
     * @param sessionBuilder The [CqlSessionBuilder] bean to use.
     * @param keyspace The [keyspace][CqlIdentifier] bean to use.
     * @return The [CqlSession] bean.
     */
    @Bean
    fun session(
        @NonNull sessionBuilder: CqlSessionBuilder,
        @Qualifier("keyspace") @NonNull keyspace: CqlIdentifier?
    ): CqlSession {
        return sessionBuilder.withKeyspace(keyspace).build()
    }
}