sanity_require (LIBRARY gtest VERSION latest)

add_executable(gtest_only main.cpp)
target_link_libraries(gtest_only gtest_main)

add_test(NAME gtest_only_test COMMAND gtest_only)
