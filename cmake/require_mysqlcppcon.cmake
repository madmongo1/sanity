include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

function (sanity_require_mysqlcppcon given_version)

# NOTE: 1.1.7 does not currently compile against the latest c connector

	set (versions 1.1.6)
	set (hashes 9e49dcfc1408b18b3d3ca02781ff7efb)
	set (mysql_versions 6.1.6)
	set (boost_versions 1.54.0)
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions mysqlcppcon version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()
#
# re-entry check
#
	if (sanity.require_mysqlcppcon.complete)
		return ()
	endif ()

#
# find index of this version in version list
# and set up dependent variables
#

	list (GET hashes ${version_index} source_hash)
	list (GET mysql_versions ${version_index} mysql_version)
	list (GET boost_versions ${version_index} boost_version)

#
# require mysql library
#
	sanity_require (LIBRARY mysql VERSION ${mysql_version})

#
# require boost library
#	
	sanity_require (LIBRARY boost VERSION ${boost_version})

# download source

	set (package_name "mysql-connector-c++-${version}")
	set (source_url "https://dev.mysql.com/get/Downloads/Connector-C++/${package_name}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (source_tree "${sanity.source.cache.source}/${package_name}")


	file(DOWNLOAD ${source_url} 
		${source_gz} 
		SHOW_PROGRESS
	    EXPECTED_HASH MD5=${source_hash})
	
# maybe untar
	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}")
		execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    					WORKING_DIRECTORY ${sanity.source.cache.source}
    					RESULT_VARIABLE res)
		if (res)
		    message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		endif ()
		sanity_touch_flag(untar_flag)
	endif()

#
# maybe configure the build
#
	find_package(Threads)
	set (build_dir ${sanity.target.build}/${package_name})
	sanity_make_flag(run_cmake_flag "target" "${package_name}" "cmake")
	if ("${untar_flag}" IS_NEWER_THAN "${run_cmake_flag}")
		set (extra_libs)
		foreach (bit IN LISTS 
				CMAKE_DL_LIBS CMAKE_THREAD_LIBS_INIT)
			string (SUBSTRING "${bit}" 0 2 prefix)
			if ("${prefix}" STREQUAL "-l")
				list (APPEND extra_libs "${bit}")
			else ()
				list (APPEND extra_libs "-l${bit}")
			endif ()
		endforeach ()
		sanity_join(mysql_libs " " ${extra_libs})
		file(MAKE_DIRECTORY ${build_dir})
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
					"-DMYSQL_LINK_FLAGS=${mysql_libs}")
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

#
# maybe build the library
#
	sanity_make_flag(run_make_flag "target" "${package_name}" "make")
	if ("${run_cmake_flag}" IS_NEWER_THAN "${run_make_flag}")
		execute_process(COMMAND make "-j${sanity.concurrency}" install 
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to build mysqlcppconn - ${res}") 
		endif ()
		sanity_touch_flag(run_make_flag)
	endif ()
	
	set (MySQLCppCon_Found TRUE)
	set (MySQLCppCon_INCLUDE_DIRS "${sanity.target.local}/include")
	
	if(EXISTS "${sanity.target.local}/lib/libmysqlcppconn-static.a")
    	set (MySQLCppCon_LIBRARIES "${sanity.target.local}/lib/libmysqlcppconn-static.a")
    	set (MySQLCppCon_LIBRARY_DIRS "${sanity.target.local}/lib")
	elseif(EXISTS "${sanity.target.local}/lib64/libmysqlcppconn-static.a")
	    set (MySQLCppCon_LIBRARY_DIRS "${sanity.target.local}/lib64")
	    set (MySQLCppCon_LIBRARIES "${sanity.target.local}/lib64/libmysqlcppconn-static.a")
	else()
	    message(FATAL_ERROR "No library found for libmysqlcppcon")
	endif()
	

	find_package(Threads)
        if (NOT TARGET sanity::mysqlcppconn)
            add_library(sanity::mysqlcppconn INTERFACE IMPORTED GLOBAL)
            target_link_libraries(sanity::mysqlcppconn INTERFACE 
                    ${MySQLCppCon_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
                    ${CMAKE_DL_LIBS} mysql sanity::boost)
        endif ()
        if (NOT TARGET mysqlcppcon)
            add_library(mysqlcppcon INTERFACE IMPORTED GLOBAL)
            target_link_libraries(mysqlcppcon INTERFACE sanity::mysqlcppconn)
        endif ()
        if (NOT TARGET mysqlcppconn)
            add_library(mysqlcppconn INTERFACE IMPORTED GLOBAL)
            target_link_libraries(mysqlcppconn INTERFACE sanity::mysqlcppconn)
        endif ()
        if (NOT TARGET sanity::mysqlcppcon)
            add_library(sanity::mysqlcppcon INTERFACE IMPORTED GLOBAL)
            target_link_libraries(sanity::mysqlcppcon INTERFACE sanity::mysqlcppconn)
        endif ()

	set (sanity.require_mysqlcppcon.complete TRUE)
	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
                                CMAKE_USE_SPROC_INIT
                                CMAKE_USE_WIN32_THREADS_INIT
                                CMAKE_USE_PTHREADS_INIT
                                CMAKE_HP_PTHREADS_INIT
                                CMAKE_DL_LIBS
                                MySQLCppCon_Found
                                MySQLCppCon_INCLUDE_DIRS 
                                MySQLCppCon_LIBRARY_DIRS 
                                MySQLCppCon_LIBRARIES
                                sanity.require_mysqlcppcon.complete)

endfunction ()
