sanity_require (LIBRARY mysql VERSION latest)

add_executable(mysql_only test_simple.cpp)
target_link_libraries(mysql_only gtest_main mysql)

add_test(NAME mysql_only_test COMMAND mysql_only)
