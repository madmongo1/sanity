include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_mysql mysql_version)

	set (versions 6.1.6)
	set (hashes cf0190bace2217d9e6d22e9e4783ae1e)
	sanity_back(versions latest_version)

	sanity_deduce_version(${mysql_version} versions mysql version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	if (sanity.require_mysql.complete)
		return ()
	endif ()

	set (package_name "mysql-connector-c-${version}-src")
	set (flag_base ${sanity.source.cache.flags}/)
	set (source_url "https://dev.mysql.com/get/Downloads/Connector-C/${package_name}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (build_dir ${sanity.target.build}/${package_name})
	set (install_prefix "${sanity.target.local}")
	list (GET hashes ${version_index} source_hash)

	if (NOT EXISTS ${source_url})
		sanity_download(URL ${source_url} PATH ${source_gz}
						HASH_METHOD MD5
						HASH_EXPECTED ${source_hash}
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	set (source_tree "${sanity.source.cache.source}/${package_name}")

	message(STATUS "building library target")
	sanity_dump_n(package_name flag_base source_url source_gz build_dir install_prefix source_tree)

	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}"
		OR "${source_gz}" IS_NEWER_THAN ${source_tree})
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

 	sanity_make_flag(configure_flag "target" "${package_name}" "configure")
	if (${untar_flag} IS_NEWER_THAN ${configure_flag} OR NOT EXISTS ${build_dir})
		file(MAKE_DIRECTORY ${build_dir})
		execute_process(
    		COMMAND ${CMAKE_COMMAND}
			-DCMAKE_CXX_FLAGS=-std=c++11 
			-DCMAKE_INSTALL_PREFIX=${install_prefix} 
			${source_tree}
    		WORKING_DIRECTORY ${build_dir}
    		RESULT_VARIABLE res
		)
		if (res)
			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
		endif ()
		sanity_touch_flag (configure_flag)
	endif ()

	sanity_make_flag(make_flag "target" "${package_name}" "make")
	if (${configure_flag} IS_NEWER_THAN ${make_flag})
		execute_process(COMMAND make "-j${sanity.concurrency}" install 
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name}")
		endif ()
		sanity_touch_flag (make_flag)
	endif ()

	find_package(Threads)

	set (MySQL_Found 1)
	set (MySQL_INCLUDE_DIRS "${install_prefix}/include")
	set (MySQL_LIBRARY_DIRS "${install_prefix}/lib")
	set (MySQL_LIBRARIES ${install_prefix}/lib/libmysqlclient_r.a ${CMAKE_THREAD_LIBS_INIT})

	set(MYSQL_FOUND ${MySQL_Found} CACHE BOOL "set by sanity" FORCE)
	set(MYSQL_INCLUDE_DIRS ${MySQL_INCLUDE_DIRS} CACHE PATH "set by sanity" FORCE)
	set(MYSQL_LIBRARY_DIRS ${MySQL_LIBRARY_DIRS} CACHE PATH "set by sanity" FORCE)
	set(MYSQL_LIBRARIES ${MySQL_LIBRARIES} CACHE STRING "set by sanity" FORCE)
	set(MYSQL_VERSION_STRING "${version}" CACHE STRING "set by sanity" FORCE)

	if (NOT TARGET mysql)
		add_library(mysql INTERFACE IMPORTED GLOBAL)
		target_link_libraries(mysql INTERFACE 
			${MySQL_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS})
		set_property(TARGET mysql 
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${MySQL_INCLUDE_DIRS})
	endif ()

	if (NOT TARGET sanity::mysql)
		add_library(sanity::mysql INTERFACE IMPORTED GLOBAL)
		target_link_libraries(sanity::mysql INTERFACE 
			${MySQL_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS})
		set_property(TARGET sanity::mysql 
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${MySQL_INCLUDE_DIRS})
	endif ()

	set (sanity.require_mysql.complete TRUE)

	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
						  CMAKE_USE_SPROC_INIT
						  CMAKE_USE_WIN32_THREADS_INIT
						  CMAKE_USE_PTHREADS_INIT
						  CMAKE_HP_PTHREADS_INIT
						  CMAKE_DL_LIBS
						  MySQL_Found 
						  MySQL_INCLUDE_DIRS 
						  MySQL_LIBRARY_DIRS 
						  MySQL_LIBRARIES
						  sanity.require_mysql.complete)

endfunction ()
