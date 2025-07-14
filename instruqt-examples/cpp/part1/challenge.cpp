// Compile with: g++ challenge.cpp [-L <dir_containing_libscylla-cpp-driver.so> -Wl,-rpath,<dir_containing_libscylla-cpp-driver.so> -I <path_to_cassandra.h>] -lscylla-cpp-driver -o challenge
// Challenge: Implement the display_all_mutants function to iterate through all columns
#include <cassandra.h>
#include <iostream>
#include <string>

class MutantApp {
private:
    CassCluster* cluster;
    CassSession* session;
    CassFuture* connect_future;

public:
    MutantApp() {
        cluster = cass_cluster_new();
        session = cass_session_new();
        
        // Add the contact points
        cass_cluster_set_contact_points(cluster, "localhost");
        
        // Connect to the cluster
        connect_future = cass_session_connect(session, cluster);
    }

    bool connect() {
        if (cass_future_error_code(connect_future) == CASS_OK) {
            std::cout << "Connected to ScyllaDB cluster" << std::endl;
            return true;
        } else {
            std::cout << "Connection ERROR" << std::endl;
            return false;
        }
    }

    // TODO: Implement this function to display all mutants with all their columns
    // The function should iterate through the result and display:
    // - first_name
    // - last_name  
    // - address
    // - picture_location
    // Format: "Name: [first_name] [last_name], Address: [address], Picture: [picture_location]"
    void display_all_mutants() {
        // TODO: Your implementation here
        // 1. Create a query to SELECT all columns from ks.mutant_data
        // 2. Execute the query
        // 3. Iterate through the results using CassIterator
        // 4. For each row, extract all column values and display them
        // 5. Don't forget to free resources!
        
        throw std::runtime_error("display_all_mutants function not implemented yet!");
    }

    void add_test_mutant() {
        const char* insert_query = "INSERT INTO ks.mutant_data (first_name, last_name, address, picture_location) VALUES ('Miles', 'Morales', '42 Brooklyn St', 'https://www.facebook.com/miles-morales')";
        CassStatement* statement = cass_statement_new(insert_query, 0);
        CassFuture* result_future = cass_session_execute(session, statement);
        
        if (cass_future_error_code(result_future) == CASS_OK) {
            std::cout << "Added test mutant: Miles Morales" << std::endl;
        } else {
            std::cout << "Failed to add test mutant" << std::endl;
        }
        
        cass_statement_free(statement);
        cass_future_free(result_future);
    }

    bool check_for_mutant(const std::string& first_name, const std::string& last_name) {
        std::string query = "SELECT * FROM ks.mutant_data WHERE first_name = '" + first_name + "' AND last_name = '" + last_name + "'";
        CassStatement* statement = cass_statement_new(query.c_str(), 0);
        CassFuture* result_future = cass_session_execute(session, statement);
        
        bool found = false;
        if (cass_future_error_code(result_future) == CASS_OK) {
            const CassResult* result = cass_future_get_result(result_future);
            CassIterator* iterator = cass_iterator_from_result(result);
            found = cass_iterator_next(iterator) != cass_false;
            cass_iterator_free(iterator);
            cass_result_free(result);
        }
        
        cass_statement_free(statement);
        cass_future_free(result_future);
        return found;
    }

    void cleanup() {
        cass_future_free(connect_future);
        cass_cluster_free(cluster);
        cass_session_free(session);
    }
};

int main() {
    MutantApp app;
    
    if (!app.connect()) {
        return 1;
    }

    std::cout << "=== Mutant Database Challenge ===" << std::endl;
    std::cout << "Current data in the database:" << std::endl;
    
    try {
        app.display_all_mutants();
    } catch (const std::runtime_error& e) {
        std::cout << "Error: " << e.what() << std::endl;
        std::cout << "Please implement the display_all_mutants function!" << std::endl;
    }

    std::cout << "\nAdding a new test mutant..." << std::endl;
    app.add_test_mutant();

    std::cout << "\nUpdated data in the database:" << std::endl;
    try {
        app.display_all_mutants();
    } catch (const std::runtime_error& e) {
        std::cout << "Error: " << e.what() << std::endl;
    }

    if (app.check_for_mutant("Miles", "Morales")) {
        std::cout << "\nCongratulations! You've successfully implemented the display_all_mutants function!" << std::endl;
        std::cout << "The function correctly iterates through all columns and displays the mutant data." << std::endl;
    } else {
        std::cout << "\nThe test mutant was not found. Make sure your implementation works correctly." << std::endl;
    }

    app.cleanup();
    return 0;
}
