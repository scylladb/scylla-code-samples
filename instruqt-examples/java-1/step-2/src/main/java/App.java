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

public static void selectQuery() {
        System.out.print("\n\nDisplaying Results:");
        ResultSet results = session.execute("SELECT * FROM catalog.mutant_data");
        for (Row row : results) {
                String first_name = row.getString("first_name");
                String last_name = row.getString("last_name");
                System.out.print("\n" + first_name + " " + last_name);
        }
}

public static void main(String[] args) {
        selectQuery();
        cluster.close();
}

}
