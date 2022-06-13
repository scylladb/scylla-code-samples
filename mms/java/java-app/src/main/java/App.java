import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;
import com.datastax.driver.core.Session;

public class App {

static Cluster cluster = Cluster.builder().addContactPoints("scylla-node1", "scylla-node2", "scylla-node3").build();
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

public static void insertQuery() {
        System.out.print("\n\nInserting Mike Tyson......");
        session.execute("INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES ('Mike','Tyson','1515 Main St', 'http://www.facebook.com/mtyson')");
        selectQuery();
}

public static void deleteQuery() {
        System.out.print("\n\nDeleting Mike Tyson......");
        session.execute("DELETE FROM mutant_data WHERE last_name = 'Tyson' and first_name = 'Mike'");
        selectQuery();
}

public static void main(String[] args) {
        selectQuery();
        insertQuery();
        deleteQuery();
        cluster.close();
}

}
