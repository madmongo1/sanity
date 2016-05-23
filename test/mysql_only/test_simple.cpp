#include <gtest/gtest.h>
#include <mysql.h>
#include <memory>

TEST(test_simple, first_test)
{
	auto closer = [](MYSQL* p) {
		mysql_close(p);
    };

	using mysql_ptr = std::unique_ptr<MYSQL, decltype(closer)>;

    auto m  = mysql_ptr { nullptr, closer };

	EXPECT_NO_THROW( m.reset(mysql_init(nullptr)) );
	EXPECT_TRUE(m.get());
	EXPECT_NO_THROW(m.reset());
}
