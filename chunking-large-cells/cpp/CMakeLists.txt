cmake_minimum_required(VERSION 3.16)
project(salted_blob_store_cpp CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# Preferred driver: ScyllaDB C++ Driver (cpp-rs-driver).
#   https://cpp-rs-driver.docs.scylladb.com/stable/
#   pkg-config module : scylla-cpp-driver
#   shared library    : libscylla-cpp-driver.so
# Falls back to the legacy DataStax cassandra driver if the Scylla package is absent.

# RPM-based distros (Rocky, Fedora) install .pc files under /usr/lib64/pkgconfig,
# which pkg-config ignores unless that path is in PKG_CONFIG_PATH.
# Homebrew (macOS) installs .pc files under /opt/homebrew/lib/pkgconfig.
set(ENV{PKG_CONFIG_PATH}
    "/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/opt/homebrew/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(CASSANDRA QUIET scylla-cpp-driver)
    if(NOT CASSANDRA_FOUND)
        pkg_check_modules(CASSANDRA QUIET cassandra)
    endif()
endif()

if(CASSANDRA_FOUND)
    # Build the interface target manually so that CASSANDRA_LIBRARY_DIRS is
    # wired in as a proper link directory. CMake 3.16's IMPORTED_TARGET does
    # not reliably propagate -L flags from pkg-config into the linker command.
    add_library(cassandra_pkgconfig INTERFACE)
    target_include_directories(cassandra_pkgconfig INTERFACE ${CASSANDRA_INCLUDE_DIRS})
    target_link_libraries(cassandra_pkgconfig INTERFACE ${CASSANDRA_LIBRARIES})
    target_link_directories(cassandra_pkgconfig INTERFACE ${CASSANDRA_LIBRARY_DIRS})
    target_compile_options(cassandra_pkgconfig INTERFACE ${CASSANDRA_CFLAGS_OTHER})
    # Embed rpath so the runtime linker finds the library without requiring
    # /usr/lib64 to be in ld.so.conf or LD_LIBRARY_PATH.
    # pkg-config may strip "system" -L paths, so fall back to /usr/lib64.
    if(CASSANDRA_LIBRARY_DIRS)
        foreach(_dir IN LISTS CASSANDRA_LIBRARY_DIRS)
            target_link_options(cassandra_pkgconfig INTERFACE "-Wl,-rpath,${_dir}")
        endforeach()
    else()
        target_link_options(cassandra_pkgconfig INTERFACE "-Wl,-rpath,/usr/lib64")
    endif()
    set(CASSANDRA_TARGET cassandra_pkgconfig)
else()
    find_path(CASSANDRA_INCLUDE_DIR
        NAMES cassandra.h
        PATHS /usr/include /usr/local/include
              /opt/homebrew/include)
    find_library(CASSANDRA_LIBRARY
        NAMES scylla-cpp-driver cassandra
        PATHS /usr/lib64 /usr/local/lib64 /usr/lib /usr/local/lib
              /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu
              /opt/homebrew/lib)
    if(NOT CASSANDRA_INCLUDE_DIR OR NOT CASSANDRA_LIBRARY)
        message(FATAL_ERROR
            "ScyllaDB C++ driver not found.\n"
            "Preferred: install scylla-cpp-driver-dev and scylla-cpp-driver (Ubuntu/Debian) or\n"
            "           scylla-cpp-driver-devel (RPM) from\n"
            "           https://cpp-rs-driver.docs.scylladb.com/stable/topics/installation.html\n"
            "Fallback : cassandra-cpp-driver-dev / libcassandra-dev (DataStax)\n"
            "Or set CMAKE_PREFIX_PATH to a custom install prefix.")
    endif()
    # Derive rpath from the full path find_library resolved.
    get_filename_component(_cassandra_lib_dir "${CASSANDRA_LIBRARY}" DIRECTORY)
    add_library(cassandra_external INTERFACE)
    target_include_directories(cassandra_external INTERFACE ${CASSANDRA_INCLUDE_DIR})
    target_link_libraries(cassandra_external INTERFACE ${CASSANDRA_LIBRARY})
    target_link_options(cassandra_external INTERFACE "-Wl,-rpath,${_cassandra_lib_dir}")
    set(CASSANDRA_TARGET cassandra_external)
endif()

add_library(salted_blob_store STATIC salted_blob_store.cpp salted_blob_store.h)
target_include_directories(salted_blob_store PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(salted_blob_store PUBLIC ${CASSANDRA_TARGET})
target_compile_options(salted_blob_store PRIVATE -Wall -Wextra -Wpedantic)

add_executable(demo demo.cpp)
target_link_libraries(demo PRIVATE salted_blob_store)
target_compile_options(demo PRIVATE -Wall -Wextra -Wpedantic)

add_executable(benchmark benchmark.cpp)
target_link_libraries(benchmark PRIVATE salted_blob_store)
target_compile_options(benchmark PRIVATE -Wall -Wextra -Wpedantic)
