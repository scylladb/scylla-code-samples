// Compile with: g++ connect.cpp [-L <dir_containing_libscylla-cpp-driver.so> -Wl,-rpath,<dir_containing_libscylla-cpp-driver.so> -I <path_to_cassandra.h>] -lscylla-cpp-driver -o connect
// Connecting to ScyllaDB with a simple C++ program
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
  } else {
    std::cout << "Connection ERROR" << std::endl;
  }
 
  // Release the resources.
  cass_future_free(connect_future);
  cass_cluster_free(cluster);
  cass_session_free(session);
}
