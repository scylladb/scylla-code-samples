import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;
import com.datastax.driver.core.Session;

public class App {

static Cluster cluster = Cluster.builder()
        .addContactPoints("localhost")
        .withPort(9042)
        .addContactPoints("localhost")
        .withPort(9043)
        .addContactPoints("localhost")
        .withPort(9044)
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

// TODO: Implement this method to add Miles Morales to the database
public static void addMilesMorales() {
        // Your challenge: Add Miles Morales to the mutant_data table
        // Use the following data:
        // first_name: "Miles"
        // last_name: "Morales"
        // address: "123 Spider Street"
        // picture_location: "http://www.marvel.com/miles-morales"
        
        System.out.print("\n\nAdding Miles Morales......");
        // TODO: Write your INSERT statement here
        // session.execute("INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES (?,?,?,?)");
        
        selectQuery();
}

public static void main(String[] args) {
        selectQuery();
        insertQuery();
        deleteQuery();
        
        // Challenge: Add Miles Morales
        addMilesMorales();
        
        System.out.println("\n\n🎉 Congratulations! You've successfully completed the ScyllaDB Java challenge!");
        cluster.close();
}

}
