#include <cassandra.h>
#include <iostream>

int main(int argc, char* argv[]) {
  CassCluster* cluster = cass_cluster_new();
  CassSession* session = cass_session_new();

  cass_cluster_set_contact_points(cluster, "localhost");

  CassFuture* connect_future = cass_session_connect(session, cluster);

  if (cass_future_error_code(connect_future) == CASS_OK) {
    std::cout << "Connected" << std::endl;
    
    const char* query = ""; // TODO: write the select query here
    CassStatement* statement = cass_statement_new(query, 0);
    
    CassFuture* result_future = cass_session_execute(session, statement);
    
    if (cass_future_error_code(result_future) == CASS_OK) {
      const CassResult* result = cass_future_get_result(result_future);
      CassIterator* iterator = cass_iterator_from_result(result);
      while (cass_iterator_next(iterator)) {
        const CassRow* row = cass_iterator_get_row(iterator);
      
        const CassValue* value = cass_row_get_column_by_name(row, "first_name");
        const char* first_name;
        size_t first_name_length;
        cass_value_get_string(value, &first_name, &first_name_length);
        std::cout.write(first_name, first_name_length);
        std::cout << '\n';
      }
      cass_iterator_free(iterator);
      cass_result_free(result);
    } else {
    }
    
    cass_statement_free(statement);
    cass_future_free(result_future);
  } else {
    std::cout << "Connection ERROR" << std::endl;
  }
 
  cass_future_free(connect_future);
  cass_cluster_free(cluster);
  cass_session_free(session);
}
