sanity_require (LIBRARY icu VERSION any)

add_executable(icu_only test_simple.cpp)
target_link_libraries(icu_only gtest_main sanity::icu)

add_test(NAME icu_only_test COMMAND icu_only)
