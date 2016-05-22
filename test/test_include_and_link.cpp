#include <mysql.h>
#include <boost/optional.hpp>
#include <boost/thread.hpp>

#include <cppconn/connection.h>

void foo()
{

}

int main()
{
	// test mysql
	MYSQL mysql;
	if(mysql_init(&mysql)) {
		mysql_close(&mysql);
	}


	// test boost
	boost::optional<int> oi(4);

	auto t = boost::thread{ &foo };
	t.join();

	return 0;
}
