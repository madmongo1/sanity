#include <gtest/gtest.h>
#include <google/protobuf/message.h>
#include <google/protobuf/arena.h>
#include <google/protobuf/util/json_util.h>
#include <google/protobuf/util/type_resolver_util.h>
#include <memory>

#include "simple.pb.h"


template<class Message>
auto make_shared_message(const std::shared_ptr<google::protobuf::Arena>& arena_ptr)
{
    using google::protobuf::Arena;
    return std::shared_ptr<Message>(arena_ptr,
                                    Arena::CreateMessage<Message>(arena_ptr.get()));
}

TEST(test_simple, first_test)
{
    auto arena = std::make_shared<google::protobuf::Arena>();
    auto message = make_shared_message<simple::Person>(arena);
    message->set_name("bob");
    message->set_id(4);
    message->set_email("foo@bar.com");
    auto phone = message->add_phone();
    phone->set_number("123456");
    phone->set_type(simple::Person_PhoneType_WORK);
    
    auto json = message->SerializeAsString();
    EXPECT_EQ("\n\x3" "bob\x10\x4\x1A\vfoo@bar.com\"\n\n\x6" "123456\x10\x2", json);
}
