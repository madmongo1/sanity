sanity_require(LIBRARY boost VERSION any)

add_executable(boost_only simple_test.cpp)
target_link_libraries(boost_only boost gtest_main)

add_test(NAME boost_only_test COMMAND boost_only)
