cmake_minimum_required(VERSION 3.5)

include(../cmake/sanity.cmake)


sanity_dump ()
sanity_require (LIBRARY mysql VERSION latest)

message(STATUS "MySQL_INCLUDE_DIRS = ${MySQL_INCLUDE_DIRS}")
message(STATUS "MySQL_LIBRARY_DIRS = ${MySQL_LIBRARY_DIRS}")
message(STATUS "MySQL_LIBRARIES = ${MySQL_LIBRARIES}")


add_executable(test_include_and_link test_include_and_link.cpp)
target_include_directories(test_include_and_link SYSTEM PRIVATE ${MySQL_INCLUDE_DIRS})
target_link_libraries(test_include_and_link mysql)

