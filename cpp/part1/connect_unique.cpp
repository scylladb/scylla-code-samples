// Compile with: g++ connect_unique.cpp [-L <dir_containing_libscylla-cpp-driver.so> -Wl,-rpath,<dir_containing_libscylla-cpp-driver.so> -I <path_to_cassandra.h>] -lscylla-cpp-driver -o conn_unique
// Connecting to ScyllaDB with a simple C++ program - demonstration of lifetime management with `unique_ptr`.
#include <cassandra.h>
#include <iostream>
#include <memory>

int main(int argc, char* argv[]) {
  // Allocate the objects that represent cluster and session. Remember to free them once no longer needed!
  auto cluster = std::unique_ptr<CassCluster, decltype(&cass_cluster_free)>(cass_cluster_new(), &cass_cluster_free);
  auto session = std::unique_ptr<CassSession, decltype(&cass_session_free)>(cass_session_new(), &cass_session_free);

  // Add the contact points. These can be either IPs or domain names.
  // You can specify more than one, comma-separated, but you don’t have to - driver will discover other nodes by itself. You should do it if you expect some of your contact points to be down.
  cass_cluster_set_contact_points(cluster.get(), "172.18.0.2"); // set the IP according to your setup


  // Connect. `cass_session_connect` returns a pointer to "future"
  // Also, this allocates the object pointed to by `connect_future`,
  //   which must be freed manually (see below).
  auto connect_future = std::unique_ptr<CassFuture, decltype(&cass_future_free)>(cass_session_connect(session.get(), cluster.get()), &cass_future_free);

  // `cass_future_error_code` will block until connected or refused.
  if (cass_future_error_code(connect_future.get()) == CASS_OK) {
    std::cout << "Connected" << std::endl;
  } else {
    std::cout << "Connection ERROR" << std::endl;
  }

  // No need to call `cass_XYZ_free` anymore - RAII will handle that once `unique_ptr`s go out of scope.
}
