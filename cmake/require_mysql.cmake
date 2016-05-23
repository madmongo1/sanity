function (sanity_deduce_version given_version versions_list_name component_name outversion outindex)

	unset (${outversion} PARENT_SCOPE)
	unset (${outindex} PARENT_SCOPE)

	if ("${given_version}" STREQUAL "latest")
		sanity_back(${versions_list_name} version)
	elseif ("${given_version}" STREQUAL "any")
		if (${${component_cache_version}})
			set (version "${${component_cache_version}}")
		else ()
			sanity_back(${versions_list_name} version)
		endif ()
	else ()
		set (version "${given_version}")
	endif ()

	list (FIND ${versions_list_name} ${version} index)
	if (${index} LESS 0)
		sanity_join(possible_versions " " ${${versions_list_name}})
		message (FATAL_ERROR "component ${component_name} requested non-existant version ${given_version}. Possible versions are ${possible_versions}")
	endif ()

	if (${${component_cache_version}})
		if ("${version}" VERSION_LESS "${${component_cache_version}}")
			message (FATAL_ERROR "component ${component_name} requires version ${given_version} but version ${${component_cache_version}} is cached")
		return ()
		endif()
	else ()
		set(${component_cache_version} "${version}" CACHE STRING "version of component ${component_name}")
	endif ()


	set (${outversion} "${version}" PARENT_SCOPE)
	set (${outindex} "${index}" PARENT_SCOPE)

endfunction ()

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
	list (GET hashes ${version_index} source_hash)

	if (NOT EXISTS ${source_gz})
		file(DOWNLOAD ${source_url} 
			${source_gz} 
			SHOW_PROGRESS
	#     	EXPECTED_HASH MD5=${source_hash}
			STATUS status
	     )
	     list (GET status 0 status_code)
	     list (GET status 1 status_string)
	     if (NOTE status_code EQUAL 0)
	     	file (REMOVE ${source_gz})
			message(FATAL_ERROR 
"error: downloading '${remote}' failed
status_code: ${status_code}
status_string: ${status_string}
log: ${log}
")
		endif ()
		file (MD5 ${source_gz} hashcode)
		if (NOT hashcode STREQUAL source_hash)
	     	file (REMOVE ${source_gz})
			message(FATAL_ERROR 
"MD5 hash mismatch
url: ${source_url}
file: ${source_gz}
expected: ${source_hash}
actual: ${hashcode}
")
		endif ()
     endif ()

	set (source_tree "${sanity.source.cache.source}/${package_name}")

	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}"
		OR NOT EXISTS ${src_tree})
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
	sanity_make_flag(configure_flag "source.cache" "${package_name}" "configure")
	if (${untar_flag} IS_NEWER_THAN ${configure_flag} OR NOT EXISTS ${build_dir})
		file(MAKE_DIRECTORY ${build_dir})
		execute_process(
    		COMMAND ${CMAKE_COMMAND}
			-DCMAKE_CXX_FLAGS=-std=c++11 
			-DCMAKE_INSTALL_PREFIX=${sanity.target.local} 
			${source_tree}
    		WORKING_DIRECTORY ${build_dir}
    		RESULT_VARIABLE res
		)
		if (res)
			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
		endif ()
		sanity_touch_flag (configure_flag)
	endif ()

	sanity_make_flag(make_flag "source.cache" "${package_name}" "make")
	if (${configure_flag} IS_NEWER_THAN ${make_flag})
		execute_process(COMMAND make -j4 install 
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name}")
		endif ()
		sanity_touch_flag (make_flag)
	endif ()

	set (MySQL_Found 1)
	set (MySQL_INCLUDE_DIRS ${sanity.target.local}/include)
	set (MySQL_LIBRARY_DIRS ${sanity.target.local}/lib)
	set (MySQL_LIBRARIES ${sanity.target.local}/lib/libmysqlclient_r.a)

	find_package(Threads)
	if (NOT TARGET mysql)
		add_library(mysql INTERFACE IMPORTED GLOBAL)
		target_link_libraries(mysql INTERFACE 
			${MySQL_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS})
		set_property(TARGET mysql 
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
