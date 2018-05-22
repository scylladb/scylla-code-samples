#include <cassandra.h>
#include <stdio.h>
#include <iostream>
using namespace std;
int main() {
        /* Setup and connect to cluster */
        CassFuture* connect_future = NULL;
        CassCluster* cluster = cass_cluster_new();
        CassSession* session = cass_session_new();

        /* Add contact points */
        cass_cluster_set_contact_points(cluster, "scylla-node1,scylla-node2,scylla-node3");

        /* Provide the cluster object as configuration to connect the session */
        connect_future = cass_session_connect(session, cluster);

        if (cass_future_error_code(connect_future) == CASS_OK) {
                CassFuture* close_future = NULL;

                /* Build statement and execute query */
                CassStatement* statement
                        = cass_statement_new("SELECT * " "FROM catalog.mutant_data", 0);

                CassFuture* result_future = cass_session_execute(session, statement);

                if(cass_future_error_code(result_future) == CASS_OK) {
                        /* Retrieve result set and iterate over the rows */
                        const CassResult* result = cass_future_get_result(result_future);
                        CassIterator* rows = cass_iterator_from_result(result);

                        while(cass_iterator_next(rows)) {
                                const CassRow* row = cass_iterator_get_row(rows);
                                const CassValue* value = cass_row_get_column_by_name(row, "first_name");
                                const CassValue* last_name_value = cass_row_get_column_by_name(row, "last_name");
                                const char* first_name;
                                size_t first_name_length;
                                const char* last_name;
                                size_t last_name_length;
                                cass_value_get_string(value, &first_name, &first_name_length);
                                cass_value_get_string(last_name_value, &last_name, &last_name_length);
                                std::cout << "\n" << last_name << "," << first_name;
                        }

                        cass_result_free(result);
                        cass_iterator_free(rows);
                } else {
                        /* Handle error */
                        const char* message;
                        size_t message_length;
                        cass_future_error_message(result_future, &message, &message_length);
                        fprintf(stderr, "Unable to run query: '%.*s'\n",
                                (int)message_length, message);
                }

                cass_statement_free(statement);
                cass_future_free(result_future);

                /* Close the session */
                close_future = cass_session_close(session);
                cass_future_wait(close_future);
                cass_future_free(close_future);
        }

        cass_future_free(connect_future);
        cass_cluster_free(cluster);
        cass_session_free(session);

        return 0;
}