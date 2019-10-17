import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;
import com.datastax.driver.core.Session;
import com.datastax.driver.core.PreparedStatement;
import com.datastax.driver.core.BoundStatement;

public class App {

static Cluster cluster = Cluster.builder().addContactPoints("scylla-node1", "scylla-node2", "scylla-node3").build();
static Session session = cluster.connect("catalog");
static PreparedStatement insert = session.prepare("INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES (?,?,?,?)");
static PreparedStatement delete = session.prepare("DELETE FROM mutant_data WHERE first_name = ? and last_name = ?");

public static void selectQuery() {
        System.out.print("\n\nDisplaying Results:");
        ResultSet results = session.execute("SELECT * FROM mutant_data");
        for (Row row : results) {
                String first_name = row.getString("first_name");
                String last_name = row.getString("last_name");
                System.out.print("\n" + first_name + " " + last_name);
        }
}

public static void insertQuery(String first_name, String last_name, String address, String picture_location) {
        System.out.print("\n\nInserting " + first_name + "......");
        session.execute(insert.bind(first_name,last_name,address,picture_location));
        selectQuery();
}

public static void deleteQuery(String first_name, String last_name) {
        System.out.print("\n\nDeleting " + first_name + "......");
        session.execute(delete.bind(first_name,last_name));
        selectQuery();
}

public static void main(String[] args) {
        selectQuery();
        insertQuery("Mike", "Tyson", "12345 Foo Lane", "http://www.facebook.com/mtyson");
        insertQuery("Alex", "Jones", "56789 Hickory St", "http://www.facebook.com/ajones");
        deleteQuery("Mike", "Tyson");
        deleteQuery("Alex", "Jones");
        cluster.close();
}

}
