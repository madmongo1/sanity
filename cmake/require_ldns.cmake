include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)



function (sanity_require_ldns given_version)

	set (library ldns)
	set (versions 1.6.17)
	set (hashes)
	list (APPEND hashes "SHA1;4218897b3c002aadfc7280b3f40cda829e05c9a4")
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions ${library} version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	set (complete_flag "sanity.require_${library}.complete")
	if (${${complete_flag}})
		return ()
	endif ()

	sanity_require(LIBRARY openssl VERSION any)

	set (package_name "${library}-${version}")
	set (flag_base ${sanity.source.cache.flags}/)
	set (source_url "https://www.nlnetlabs.nl/downloads/${library}/${library}-${version}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (build_dir ${sanity.target.build}/${package_name})
	set (untar_root "${sanity.source.cache.source}")
	set (source_tree "${untar_root}/${package_name}")
	math (EXPR hash_type_index "${version_index} * 2")
	math (EXPR hash_value_index "${hash_type_index} + 1")
	list (GET hashes ${hash_type_index} hash_method)
	list (GET hashes ${hash_value_index} source_hash)

	if (NOT EXISTS ${source_url})
		MESSAGE (STATUS "${package_name}: Downloading [${source_url}] to [${source_gz}]")
		sanity_download(URL ${source_url} PATH ${source_gz}
						HASH_METHOD ${hash_method}
						HASH_EXPECTED ${source_hash}
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	sanity_make_flag(patch_flag "source.cache" "${package_name}" "patch")
	sanity_make_flag(configure_flag "target" "${package_name}" "configure")

	if (NOT EXISTS ${source_tree} OR NOT EXISTS ${untar_flag})
		MESSAGE (STATUS "${package_name}: Untaring [${source_gz}] into [${untar_root}]")
    	execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
						WORKING_DIRECTORY ${untar_root}
						RESULT_VARIABLE res)
	    if (res)
	    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
	    endif ()
		sanity_touch_flag(untar_flag)
	endif()

	if (${untar_flag} IS_NEWER_THAN ${patch_flag})
		if ("${version}" STREQUAL "1.6.17")
			set (patch_file "${sanity.root}/patch/ldns-1.6.17.patch")

			MESSAGE (STATUS "${package_name}: patching [${source_tree}] WITH file [${patch_file}]")

			MESSAGE (STATUS "cd ${source_tree}")
			MESSAGE (STATUS "git apply ${patch_file}")
			execute_process(COMMAND "git" "apply" "${patch_file}"
							WORKING_DIRECTORY "${source_tree}"
							RESULT_VARIABLE res)
			if (res)
				MESSAGE(FATAL_ERROR "during patch: ${res}") 
			endif ()
		endif ()
		sanity_touch_flag(patch_flag)
	endif ()


	if (${patch_flag} IS_NEWER_THAN ${configure_flag})
		file (MAKE_DIRECTORY ${build_dir})
		MESSAGE (STATUS "${package_name}: configuring")
		set (configure_command "${source_tree}/configure")
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--with-ssl=${sanity.target.local}/ssl")
		list (APPEND configure_command "--enable-shared=no")
		list (APPEND configure_command "--enable-static=yes")
		list (APPEND configure_command "--disable-rpath")
		execute_process(COMMAND ${configure_command} 
				    	WORKING_DIRECTORY ${build_dir}
				    	RESULT_VARIABLE res)
		if (res)
			sanity_join (cmd_line " " ${configure_command})
			message (FATAL_ERROR "${cmd_line} 
error code : ${res}"
				)
		endif ()
		sanity_touch_flag (configure_flag)
	endif ()


	sanity_make_flag(clean_flag "target" "${package_name}" "clean")
	sanity_make_flag(make_flag "target" "${package_name}" "make")

	if (${configure_flag} IS_NEWER_THAN ${clean_flag})
		MESSAGE (STATUS "${package_name}: cleaning")
		file (MAKE_DIRECTORY "${build_dir}")
		execute_process(COMMAND make "-j${sanity.concurrency}" clean
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(clean_flag)
	endif ()

	if (${clean_flag} IS_NEWER_THAN ${make_flag} OR NOT EXISTS ${make_flag})

		MESSAGE (STATUS "${package_name}: building")
		execute_process(COMMAND make "-j${sanity.concurrency}"
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name} - error code ${res}")
		endif ()
		MESSAGE (STATUS "${package_name}: installing")
		execute_process(COMMAND make install
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to install ${package_name} - error code ${res}")
		endif ()
		sanity_touch_flag (make_flag)
	endif ()

	find_package(Threads)
	set(component_names LDNS_INCLUDE_DIRS LDNS_LIBRARIES LDNS_FOUND LDNS_VERSION_STRING)
	set(LDNS_INCLUDE_DIRS "${sanity.target.local}/include")
	set(LDNS_LIBRARIES "${sanity.target.local}/lib/libldns.a")
	set(LDNS_FOUND True)
	set(LDNS_VERSION_STRING "${version}")

	if (NOT TARGET sanity::ldns)
		add_library(sanity::ldns INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::ldns 
                                INTERFACE ${LDNS_LIBRARIES} ${OPENSSL_LIBRARIES})
		set_property(TARGET sanity::ldns
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${LDNS_INCLUDE_DIRS} ${OPENSSL_INCLUDE_DIR})
	endif ()

	set (${complete_flag} TRUE)

	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
						  CMAKE_USE_SPROC_INIT
						  CMAKE_USE_WIN32_THREADS_INIT
						  CMAKE_USE_PTHREADS_INIT
						  CMAKE_HP_PTHREADS_INIT
						  CMAKE_DL_LIBS
						  ${component_names}
						  ${complete_flag})


endfunction()