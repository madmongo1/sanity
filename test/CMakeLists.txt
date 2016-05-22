cmake_minimum_required(VERSION 3.5)

include(../cmake/sanity.cmake)

#deliberately include more than once to test that this has no effect
include(../cmake/sanity.cmake)


sanity_dump ()
sanity_require (LIBRARY mysql VERSION latest)
sanity_require (LIBRARY mysql VERSION latest)
sanity_require (LIBRARY mysqlcppcon VERSION latest)

message(STATUS "MySQL_INCLUDE_DIRS = ${MySQL_INCLUDE_DIRS}")
message(STATUS "MySQL_LIBRARY_DIRS = ${MySQL_LIBRARY_DIRS}")
message(STATUS "MySQL_LIBRARIES = ${MySQL_LIBRARIES}")


add_executable(test_include_and_link test_include_and_link.cpp)
target_link_libraries(test_include_and_link mysqlcppcon boost_thread)

