import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.ResultSet;
import com.datastax.driver.core.Row;
import com.datastax.driver.core.Session;
import com.datastax.driver.core.PreparedStatement;
import com.datastax.driver.core.BoundStatement;
import com.datastax.driver.core.*;
import com.datastax.driver.core.utils.Bytes;
import java.io.*;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.util.HashMap;
import java.util.Map;

public class DataTypes_App {

static File FILE;
// Add static PreparedStatement fields to avoid re-preparing
static PreparedStatement insertDataStatement;
static PreparedStatement insertBlobStatement;  
static PreparedStatement selectStatement;

public static void main(String[] args) {
        Cluster cluster = Cluster.builder()
                .addContactPoints("localhost")
                .withPort(9042)
                .build();
        Session session = cluster.connect("catalog");
        createSchema(session);
        
        // Prepare all statements once at the beginning
        prepareStatements(session);

        String[] mutants = new String[] {"Jim Jefferies", "Bob Loblaw", "Bob Zemuda"};
        for (int i=0; i != mutants.length; i++) {
                if(mutants[i] != null) {
                        String[] first_name = mutants[i].split(" ");
                        String last_name = first_name[1];
                        FILE = new File(first_name[0] + "_" + last_name + ".png");
                        System.out.print("\nProcessing image for: " + first_name[0] + " " + last_name);
                        allocateAndInsert(session, first_name[0], last_name);
                        insertConcurrent(session, first_name[0], last_name);
                        try {
                                insertFromAndRetrieveToFile(session, first_name[0], last_name);
                        } catch (IOException e) {
                                System.out.println("Got IOException while retrieving data and writing to file:");
                                e.printStackTrace();
                        }
                        
                }
        }
        cluster.close();

}

// Add method to prepare all statements once
private static void prepareStatements(Session session) {
        insertDataStatement = session.prepare("INSERT INTO catalog.mutant_data (first_name, last_name, b, m) VALUES (?, ?, ?, ?)");
        insertBlobStatement = session.prepare("INSERT INTO catalog.mutant_data (first_name, last_name, b) VALUES (?, ?, ?)");

        // TODO: Complete the prepared statement declaration by adding the appropriate WHERE clause
        selectStatement = session.prepare("SELECT b FROM catalog.mutant_data"); 
}

private static void createSchema(Session session) {
        try {
                session.execute("ALTER table catalog.mutant_data ADD b blob");
                session.execute("ALTER table catalog.mutant_data ADD m map<text, blob>");
        } catch (Exception schema) {
        }

}

private static void allocateAndInsert(Session session, String first_name, String last_name) {
        ByteBuffer buffer = ByteBuffer.allocate(16);
        while (buffer.hasRemaining()) buffer.put((byte) 0xFF);
        assert buffer.limit() - buffer.position() == 0;

        buffer.flip();
        assert buffer.limit() - buffer.position() == 16;

        Map<String, ByteBuffer> map = new HashMap<String, ByteBuffer>();
        map.put(first_name + "_" + last_name + ".png", buffer);
        session.execute(insertDataStatement.bind(first_name,last_name,buffer,map));
}

private static void insertConcurrent(Session session, String first_name, String last_name) {
        ByteBuffer buffer = Bytes.fromHexString("0xffffff");
        session.execute(insertBlobStatement.bind(first_name,last_name,buffer));
        buffer.position(buffer.limit());
        buffer.flip();
}

private static void insertFromAndRetrieveToFile(Session session, String first_name, String last_name) throws IOException {
        ByteBuffer buffer = readAll(FILE);
        session.execute(insertBlobStatement.bind(first_name,last_name,buffer));

        File tmpFile = new File("/tmp/" + first_name + "_" + last_name + ".png");
        System.out.printf("\nWriting retrieved buffer to %s%n ", tmpFile.getAbsoluteFile());

        Row row = session.execute(selectStatement.bind(first_name,last_name)).one();
        writeAll(row.getBytes("b"), tmpFile);
}

private static ByteBuffer readAll(File file) throws IOException {
        FileInputStream inputStream = null;
        boolean threw = false;
        try {
                inputStream = new FileInputStream(file);
                FileChannel channel = inputStream.getChannel();
                ByteBuffer buffer = ByteBuffer.allocate((int) channel.size());
                channel.read(buffer);
                buffer.flip();
                return buffer;
        } catch (IOException e) {
                threw = true;
                throw e;
        } finally {
                close(inputStream, threw);
        }
}

private static void writeAll(ByteBuffer buffer, File file) throws IOException {
        FileOutputStream outputStream = null;
        boolean threw = false;
        try {
                outputStream = new FileOutputStream(file);
                FileChannel channel = outputStream.getChannel();
                channel.write(buffer);
        } catch (IOException e) {
                threw = true;
                throw e;
        } finally {
                close(outputStream, threw);
        }
}

private static void close(Closeable inputStream, boolean threw) throws IOException {
        if (inputStream != null)
                try {
                        inputStream.close();
                } catch (IOException e) {
                        if (!threw) throw e; // else preserve original exception
                }
}
}
