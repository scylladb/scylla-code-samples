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

public class App {

static File FILE;

public static void main(String[] args) {
        try {
                Cluster cluster = Cluster.builder().addContactPoints("scylla-node1", "scylla-node2", "scylla-node3").build();
                Session session = cluster.connect("catalog");
                createSchema(session);

                String[] mutants = new String[] {"Jim Jefferies", "Bob Loblaw", "Bob Zemuda"};
                for (int i=0; i != mutants.length; i++) {
                        if(mutants[i] != null) {
                                String[] first_name = mutants[i].split(" ");
                                String last_name = first_name[1];
                                FILE = new File("/opt/code/" + first_name[0] + "_" + last_name + ".png");
                                System.out.print("\nProcessing image for: " + first_name[0] + " " + last_name);
                                allocateAndInsert(session, first_name[0], last_name);
                                insertConcurrent(session, first_name[0], last_name);
                                insertFromAndRetrieveToFile(session, first_name[0], last_name);
                        }
                }
                cluster.close();
        } catch (Exception main) {
                System.out.print("\n" + main.getMessage());
        }

}
private static void createSchema(Session session) {
        try {
                session.execute("ALTER table catalog.mutant_data ADD b blob");
                session.execute("ALTER table catalog.mutant_data ADD m map<text, blob>");
        } catch (Exception schema) {
        }

}

private static void allocateAndInsert(Session session, String first_name, String last_name) {
        PreparedStatement insertData = session.prepare("INSERT INTO catalog.mutant_data (first_name, last_name, b, m) VALUES (?, ?, ?, ?)");

        ByteBuffer buffer = ByteBuffer.allocate(16);
        while (buffer.hasRemaining()) buffer.put((byte) 0xFF);
        assert buffer.limit() - buffer.position() == 0;

        buffer.flip();
        assert buffer.limit() - buffer.position() == 16;

        Map<String, ByteBuffer> map = new HashMap<String, ByteBuffer>();
        map.put(first_name + "_" + last_name + ".png", buffer);
        session.execute(insertData.bind(first_name,last_name,buffer,map));
}

private static void insertConcurrent(Session session, String first_name, String last_name) {
        PreparedStatement preparedStatement = session.prepare("INSERT INTO catalog.mutant_data (first_name, last_name, b) VALUES (?, ?, ?)");
        ByteBuffer buffer = Bytes.fromHexString("0xffffff");
        session.execute(preparedStatement.bind(first_name,last_name,buffer));
        buffer.position(buffer.limit());
        buffer.flip();
}

private static void insertFromAndRetrieveToFile(Session session, String first_name, String last_name) throws IOException {
        ByteBuffer buffer = readAll(FILE);
        PreparedStatement insertFrom = session.prepare("INSERT INTO catalog.mutant_data (first_name, last_name, b) VALUES (?, ?, ?)");
        session.execute(insertFrom.bind(first_name,last_name,buffer));

        File tmpFile = new File("/tmp/" + first_name + "_" + last_name + ".png");
        System.out.printf("\nWriting retrieved buffer to %s%n ", tmpFile.getAbsoluteFile());

        PreparedStatement get = session.prepare("SELECT b FROM catalog.mutant_data WHERE first_name = ? AND last_name = ?");
        Row row = session.execute(get.bind(first_name,last_name)).one();
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
