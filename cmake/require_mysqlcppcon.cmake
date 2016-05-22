function (sanity_require_mysqlcppcon version)

# NOTE: 1.1.7 does not currently compile against the latest c connector
    set (latest_version 1.1.6)

	set (versions 1.1.6)
	set (hashes 9e49dcfc1408b18b3d3ca02781ff7efb)
	set (mysql_versions 6.1.6)
	set (boost_versions 1.54.0)

	if (version STREQUAL "latest")
		sanity_require_mysqlcppcon (${latest_version})
	else ()
		if (NOT sanity.mysqlcppcon.version)
			set(sanity.mysqlcppcon.version ${version} CACHE STRING "version of mysqlcppcon required")
		endif ()

		if (sanity.mysqlcppcon.version VERSION_LESS version)
			message (FATAL_ERROR "mysqlcppcon version ${version} specified but lower version ${sanity.mysqlcppcon.version} already built")
		endif()

		list (FIND versions "${sanity.mysqlcppcon.version}" version_index)
		if (version_index LESS 0)
			message (FATAL_ERROR "unknown version of mysqlcppcon: ${sanity.mysqlcppcon.version}")
		endif ()

		if (sanity.require_mysqlcppcon.complete)
			return ()
		endif ()

		list (GET mysql_versions ${version_index} mysql_version)
		sanity_require (LIBRARY mysql VERSION ${mysql_version})
		list (GET boost_versions ${version_index} boost_version)
		sanity_require (LIBRARY boost VERSION ${boost_version})

		set (package_name "mysql-connector-c++-${version}")
		set (source_url "https://dev.mysql.com/get/Downloads/Connector-C++/${package_name}.tar.gz")
		set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
		list (GET hashes ${version_index} source_hash)
		file(DOWNLOAD ${source_url} 
			${source_gz} 
			SHOW_PROGRESS
	     	EXPECTED_HASH MD5=${source_hash})
	    set (source_tree "${sanity.source.cache.source}/${package_name}")

	    sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")

	    if ("${source_url}" IS_NEWER_THAN "${untar_flag}")
	     	execute_process(
    			COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    			WORKING_DIRECTORY ${sanity.source.cache.source}
    			RESULT_VARIABLE res
		    	)
		    if (res)
		    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		    endif ()
		    sanity_touch_flag(untar_flag)
		endif()

		set (build_dir ${sanity.target.build}/${package_name})
		sanity_make_flag(run_cmake_flag "target" "${package_name}" "cmake")
		if ("${untar_flag}" IS_NEWER_THAN "${run_cmake_flag}")
			sanity_join(mysql_libs " " ${CMAKE_DL_LIBS} ${CMAKE_THREAD_LIBS_INIT})
			file(MAKE_DIRECTORY ${build_dir})
			message(STATUS "executing : ${CMAKE_COMMAND} ${source_tree}")
			message(STATUS "directory : ${build_dir}")
			set (args)
			list(APPEND args 	   			
				-DBOOST_ROOT=${Boost_ROOT}
	   			-DBoost_NO_SYSTEM_PATHS=ON
	   			"-DBOOST_INCLUDEDIR=${sanity.target.local}/include"
	   			"-DBOOST_LIBRARYDIR=${sanity.target.local}/lib"
				-DCMAKE_ENABLE_C++11=ON
				-DMYSQLCLIENT_STATIC_LINKING=ON
				"-DCMAKE_INSTALL_PREFIX=${sanity.target.local}"
				"-DMYSQL_DIR=${sanity.target.local}"
				"-DDMYSQL_INCLUDE_DIR=${sanity.target.local}/include"
				"-DMYSQL_LIB_DIR=${sanity.target.local}/lib")
			if (NOT "${mysql_libs}" STREQUAL "") 
				list (APPEND args
				"-DMYSQL_LINK_FLAGS=\"${mysql_libs}\"")
			endif ()
			execute_process(
	   			COMMAND ${CMAKE_COMMAND}
	   			${args}
				${source_tree}
	   			WORKING_DIRECTORY ${build_dir}
 	 			RESULT_VARIABLE res)
			if (res)
				message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
			endif ()
			sanity_touch_flag(run_cmake_flag)
		endif ()
#		execute_process(COMMAND ${CMAKE_MAKE_PROGRAM} -j4 install 
#						WORKING_DIRECTORY ${build_dir})
#		set (MySQL_Found 1)
#		set (MySQL_INCLUDE_DIRS ${sanity.target.local}/include)
#		set (MySQL_LIBRARY_DIRS ${sanity.target.local}/lib)
#		set (MySQL_LIBRARIES ${sanity.target.local}/lib/libmysqlclient_r.a)
#
#		find_package(Threads)
#		add_library(mysql INTERFACE IMPORTED GLOBAL)
#		target_link_libraries(mysql INTERFACE 
#			${MySQL_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
#			${CMAKE_DL_LIBS})
		set (sanity.require_mysqlcppcon.complete TRUE)
#			sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
#								  CMAKE_USE_SPROC_INIT
#								  CMAKE_USE_WIN32_THREADS_INIT
#								  CMAKE_USE_PTHREADS_INIT
#								  CMAKE_HP_PTHREADS_INIT
#								  CMAKE_DL_LIBS
#								  sanity.require_mysqlcppcon.complete)
	endif()

	# now that we have built, we can set the cache values for this module 
	sanity_propagate_vars (MySQLCppCon_Found MySQLCppCon_INCLUDE_DIRS MySQLCppCon_LIBRARY_DIRS MySQLCppCon_LIBRARIES)

endfunction ()