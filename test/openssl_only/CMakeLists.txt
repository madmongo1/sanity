sanity_require (LIBRARY openssl VERSION any)

add_executable(openssl_only test_simple.cpp)
target_link_libraries(openssl_only gtest_main sanity::openssl)

add_test(NAME openssl_only_test COMMAND openssl_only)
