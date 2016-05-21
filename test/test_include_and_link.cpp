#include <mysql.h>

int main()
{
	// test mysql
	MYSQL mysql;
	if(mysql_init(&mysql)) {
		mysql_close(&mysql);
	}


	return 0;
}
