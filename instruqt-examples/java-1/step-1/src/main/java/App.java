import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;
import com.datastax.driver.core.Session;

public class App {

static Cluster cluster = Cluster.builder()
        .addContactPoints("localhost")
        .withPort(9042)
        .build();

static Session session = cluster.connect("catalog");

public static void main(String[] args) {
        System.out.println("Successfully connected to ScyllaDB database!");
        cluster.close();
}

}
