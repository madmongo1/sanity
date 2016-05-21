function (sanity_require_boost version)

    set (latest_version 1.61.0)
	set (versions 1.61.0)
	set (hashes cf0190bace2217d9e6d22e9e4783ae1e)

	if (version STREQUAL "latest")
		sanity_require_boost (${latest_version})
		sanity_propagate_vars ()
	endif ()

	if (NOT sanity.boost.version)
		if (version VERSION_LESS latest_version)
			set (version ${latest_version})
		endif ()
		set(sanity.boost.version ${version} CACHE STRING "version of boost chosen")
	endif ()

	if (sanity.boost.version VERSION_LESS version)
		message (FATAL_ERROR "boost version ${version} specified but lower version ${sanity.boost.version} already built")
		return()
	endif()

		list (FIND versions "${sanity.boost.version}" version_index)
		if (version_index LESS 0)
			message (FATAL_ERROR "unknown version of boost: ${sanity.boost.version}")
		endif ()

		if (sanity.boost.complete)
			return ()
		endif ()

		set (package_name "mysql-connector-c-${mysql_version}-src")
		set (flag_base ${sanity.source.cache.flags}/)
		set (source_url "https://dev.mysql.com/get/Downloads/Connector-C/${package_name}.tar.gz")
		set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
		list (GET hashes ${version_index} source_hash)
		file(DOWNLOAD ${source_url} 
			${source_gz} 
			SHOW_PROGRESS
	     	EXPECTED_HASH MD5=${source_hash} 
	     )

	     set (source_tree "${sanity.source.cache.source}/${package_name}")

	     if (NOT EXISTS ${src_tree})
	     	execute_process(
    			COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    			WORKING_DIRECTORY ${sanity.source.cache.source}
    			RESULT_VARIABLE res
		    	)
		    if (res)
		    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		    endif ()
		 endif()

		set (build_dir ${sanity.target.build}/${package_name})
		file(MAKE_DIRECTORY ${build_dir})
#		message(STATUS "executing : ${CMAKE_COMMAND} ${source_tree}")
#		message(STATUS "directory : ${build_dir}")
#		execute_process(
#    		COMMAND ${CMAKE_COMMAND}
#			-DCMAKE_CXX_FLAGS=-std=c++11 
#			-DCMAKE_INSTALL_PREFIX=${sanity.target.local} 
#			${source_tree}
#   		WORKING_DIRECTORY ${build_dir}
#    		RESULT_VARIABLE res
#		)
#		if (res)
#			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
#		endif ()
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

		set (sanity.require_boost.complete TRUE)
#
#			sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
#								  CMAKE_USE_SPROC_INIT
#								  CMAKE_USE_WIN32_THREADS_INIT
#								  CMAKE_USE_PTHREADS_INIT
#								  CMAKE_HP_PTHREADS_INIT
#								  CMAKE_DL_LIBS
#								  sanity.require_boost.complete)

	# now that we have built, we can set the cache values for this module 
	sanity_propagate_vars ()

endfunction ()
