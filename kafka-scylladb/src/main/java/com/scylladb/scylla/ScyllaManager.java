package com.scylladb.scylla;

import com.datastax.driver.core.*;
import org.apache.commons.lang.StringUtils;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.*;

// Manage Scylla connection & operations.
public class ScyllaManager {
    private static ScyllaManager instance = null;
    private Properties scyllaConfigProperties = null;
    // Cluster & Session objects.
    private Cluster cluster;
    private Session session;
    // Since we are only considering one type of query and one table structure, we can have a single PreparedStatement
    private PreparedStatement ps;

    // avoid direct instantiation.
    protected ScyllaManager() {
    }

    /**
     * Get instance for this thread, singleton pattern.
     */
    public static ScyllaManager getInstance(Properties scyllaConfigProperties) {
        if (instance == null) {
            instance = new ScyllaManager();
            instance.scyllaConfigProperties = scyllaConfigProperties;
            System.out.println("Connecting to Scylla Cluster "
                    + instance.scyllaConfigProperties.getProperty("scylla.host") + " at keyspace: "
                    + instance.scyllaConfigProperties.getProperty("scylla.keyspace"));
            instance.cluster = Cluster.builder()
                    .addContactPoints(instance.scyllaConfigProperties.getProperty("scylla.host"))
                    .build();
            instance.session = instance.cluster.connect(instance.scyllaConfigProperties.getProperty("scylla.keyspace"));
            instance.ps = null;
        }
        return instance;
    }

    /**
     * Terminate the singleton instance.
     */
    public static void terminate() {
        if (instance != null) {
            instance = null;
            System.out.println("Terminating Scylla Manager");
        }
    }

    /**
     * Simple query functionality.
     *
     * @param query
     * @return
     * @throws Exception
     */
    public Iterator<Row> query(String query) throws Exception {
        if (instance == null) throw new Exception("Initialize the ScyllaManager first");
        return session.execute(query).iterator();
    }


    /**
     * We do this because we have only one table in this example.
     *
     * @param params
     */
    private void buildPreparedStatement(Map<String, String> params) {
        // Parse map to query
        ArrayList<String> keys = new ArrayList<>(params.keySet());
        Collections.sort(keys);

        instance.ps = instance.session.prepare(
                String.format(
                        "INSERT INTO %s.%s (%s) VALUES (%s)",
                        instance.scyllaConfigProperties.getProperty("scylla.keyspace"),
                        instance.scyllaConfigProperties.getProperty("scylla.table"),
                        StringUtils.join(keys, ","),
                        StringUtils.join(Collections.nCopies(keys.size(), "?"), ",")
                )
        );
    }

    /**
     * Insert into Scylla
     *
     * @param params: Key-Value pairs providing the new record to insert.
     * @throws Exception
     */
    public void insert(Map<String, String> params) throws Exception {
        if (instance == null) throw new Exception("Initialize the ScyllaManager first");
        if (instance.ps == null) {
            instance.buildPreparedStatement(params);
        }

        // Parse map to query
        ArrayList<String> keys = new ArrayList<>(params.keySet());
        Collections.sort(keys);
        ArrayList<String> values = new ArrayList<>();

        DateFormat df = new SimpleDateFormat("yyyy-MM-dd");

        BoundStatement bound = instance.ps.bind();
        for (int i = 0; i < keys.size(); i++) {
            String key = keys.get(i);
            if (!key.equals("date")) {
                bound.setString(i, params.get(key));
            } else {
                bound.setTimestamp(i, df.parse(params.get(key)));
            }
        }
        // Execute the insert statement, we don't care about retrieving a result on insert, so we can do async.
        session.executeAsync(bound);
    }
}
