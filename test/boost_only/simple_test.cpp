#include <gtest/gtest.h>
#include <boost/format.hpp>
#include <sstream>
#include <string>

TEST(test_simple, format)
{
	std::ostringstream ss;
	int chickens = 5;
	std::string farm = "farm";

	ss << boost::format("old macdonald had a %1% and on that farm he had %2% chickens") % farm % chickens;
	EXPECT_EQ("old macdonald had a farm and on that farm he had 5 chickens", ss.str());
}