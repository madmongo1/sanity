sanity_require (LIBRARY protobuf VERSION latest)

protobuf_configure_files (	FILES simple.proto 
							CPP
							CPP_HEADERS proto_hdrs 
							CPP_SOURCES proto_srcs)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
add_executable(protobuf_only test_simple.cpp ${proto_hdrs} ${proto_srcs})
target_link_libraries(protobuf_only gtest_main sanity::protobuf)

add_test(NAME protobuf_only_test COMMAND protobuf_only)
