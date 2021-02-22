// Compile with: g++ param_simple.cpp [-L <dir_containing_libscylla-cpp-driver.so> -Wl,-rpath,<dir_containing_libscylla-cpp-driver.so> -I <path_to_cassandra.h>] -lscylla-cpp-driver -o param_simple
// Example of parametrized simple query. DB is expected to have some data in `ks.mutant_data`!
#include <cassandra.h>
#include <iostream>

int main(int argc, char* argv[]) {
  // Allocate the objects that represent cluster and session. Remember to free them once no longer needed!
  CassCluster* cluster = cass_cluster_new();
  CassSession* session = cass_session_new();

  // Add the contact points. These can be either IPs or domain names.
  // You can specify more than one, comma-separated, but you don’t have to - driver will discover other nodes by itself. You should do it if you expect some of your contact points to be down.
  cass_cluster_set_contact_points(cluster, "172.18.0.2"); // set the IP according to your setup

  // Connect. `cass_session_connect` returns a pointer to "future"
  // Also, this allocates the object pointed to by `connect_future`,
  //   which must be freed manually (see below).
  CassFuture* connect_future = cass_session_connect(session, cluster);

  // `cass_future_error_code` will block until connected or refused.
  if (cass_future_error_code(connect_future) == CASS_OK) {
    std::cout << "Connected" << std::endl;
    
    // Fetch data sample from ScyllaDB after the connection is established
    const char* query = "SELECT first_name, last_name, address, picture_location FROM ks.mutant_data";
    // Parameterized simple statement, not to be confused with prepared statements!
    CassStatement* statement = cass_statement_new("SELECT * FROM ks.mutant_data WHERE first_name=? and last_name=?", 2); // `2` is the number of parameters
    
    cass_statement_bind_string(statement, 0, "Bob");
    cass_statement_bind_string(statement, 1, "Loblaw");
    
    // Proceed with `statement` as usual
    CassFuture* result_future = cass_session_execute(session, statement);
    
    if (cass_future_error_code(result_future) == CASS_OK) {
      const CassResult* result = cass_future_get_result(result_future);
      const CassRow* row = cass_result_first_row(result);
    
      if (row) {
        const CassValue* value = cass_row_get_column_by_name(row, "address");
    
        const char* address;
        size_t address_length;
        cass_value_get_string(value, &address, &address_length);
	std::cout << "Address for Bob Loblaw is: "; 
	std::cout.write(address, address_length);
	std::cout << std::endl;

      }
    
      cass_result_free(result);
    } else {
      // Handle error - omitted for brevity
    }
    
    cass_statement_free(statement);
    cass_future_free(result_future);
  } else {
    std::cout << "Connection ERROR" << std::endl;
  }
 
  // Release the resources.
  cass_future_free(connect_future);
  cass_cluster_free(cluster);
  cass_session_free(session);
}
