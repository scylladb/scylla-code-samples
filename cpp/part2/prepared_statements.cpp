// Compile with: g++ prepared_statements.cpp [-L <dir_containing_libscylla-cpp-driver.so> -Wl,-rpath,<dir_containing_libscylla-cpp-driver.so> -I <path_to_cassandra.h>] -lscylla-cpp-driver -o prepared_statements
// Demonstration of prepared statements. Table `ks.mutant_data` is expected to exist!
#include <cassandra.h>
#include <iostream>

int main(int argc, char* argv[]) {
  // Allocate the objects that represent cluster and session. Remember to free them once no longer needed!
  CassCluster* cluster = cass_cluster_new();
  CassSession* session = cass_session_new();

  // Add the contact points. These can be either IPs or domain names.
  // You can specify more than one, comma-separated, but you don’t have to - driver will discover other nodes by itself. You should do it if you expect some of your contact points to be down.
  cass_cluster_set_contact_points(cluster,"172.18.0.2"); // set the IP according to your setup

  // Connect. `cass_session_connect` returns a pointer to "future"
  // Also, this allocates the object pointed to by `connect_future`,
  //   which must be freed manually (see below).
  CassFuture* connect_future = cass_session_connect(session, cluster);

  // `cass_future_error_code` will block until connected or refused.
  if (cass_future_error_code(connect_future) == CASS_OK) {
    std::cout << "Connected" << std::endl;
    
    // Imagine we have a lot of mutants to INSERT and we don’t know their addresses nor do we have their pictures
    const char* query = "INSERT INTO ks.mutant_data (first_name, last_name, address, picture_location) VALUES (?, ?, 'unknown', 'no picture');"; // Note the question marks
    
    CassFuture* prep_future = cass_session_prepare(session, query); // Send the “templated” query to Scylla to “compile” it.
    cass_future_wait(prep_future); // Preparing (“compiling”) the query is an async operation.
    const CassPrepared* prepared = cass_future_get_prepared(prep_future); // This object will be reused for every similar INSERT
    cass_future_free(prep_future);
    
    // Now this code block can be repeated, effectively performing similar INSERTs - with various values in places of question marks
    {
      CassStatement* bound_statement = cass_prepared_bind(prepared);
      cass_statement_bind_string(bound_statement, 0, "Aaron"); // Fill in the first question mark
      cass_statement_bind_string(bound_statement, 1, "Goldstein"); // Fill in the second question mark
    
      // Proceed as usual:
      CassFuture* exec_future = cass_session_execute(session, bound_statement);
      cass_future_wait(exec_future);
      
      std::cout << "Inserting data using Prepared Statement" << std::endl;

      cass_future_free(exec_future);
      cass_statement_free(bound_statement);
    }
    
    cass_prepared_free(prepared);
  } else {
    std::cout << "Connection ERROR" << std::endl;
  }
 
  // Release the resources.
  cass_future_free(connect_future);
  cass_cluster_free(cluster);
  cass_session_free(session);
}
