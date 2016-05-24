include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_openssl given_version)

	set (versions 1.0.2h)
	set (hashes)
	list (APPEND hashes "SHA256;1d4007e53aad94a5b2002fe045ee7bb0b3d98f1a47f8b2bc851dcd1c74332919")
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions openssl version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	if (sanity.require_openssl.complete)
		return ()
	endif ()

	set (package_name "openssl-${version}")
	set (source_url "https://www.openssl.org/source/${package_name}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	# source must be configured in its own tree :(
	set (untar_root "${sanity.target.local.source}")
	set (source_tree "${untar_root}/${package_name}")
	set (build_dir ${source_tree})
	math (EXPR hash_type_index "${version_index} * 2")
	math (EXPR hash_value_index "${hash_type_index} + 1")
	list (GET hashes ${hash_type_index} hash_method)
	list (GET hashes ${hash_value_index} source_hash)

	if (NOT EXISTS ${source_url})
		sanity_download(URL "${source_url}" PATH "${source_gz}"
						HASH_METHOD "${hash_method}"
						HASH_EXPECTED "${source_hash}"
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()


	sanity_make_flag(untar_flag "target" "${package_name}" "untar")
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}"
		OR "${source_gz}" IS_NEWER_THAN ${source_tree})
     	execute_process(
			COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
			WORKING_DIRECTORY ${untar_root}
			RESULT_VARIABLE res
	    	)
	    if (res)
	    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
	    endif ()
		sanity_touch_flag(untar_flag)
	endif()


	sanity_make_flag(configure_flag "target" "${package_name}" "configure")
	if (${untar_flag} IS_NEWER_THAN ${configure_flag})
		set (configure_command )
		if (APPLE)
#message(FATAL_ERROR "Apple path")
			set (configure_command "${source_tree}/Configure" "darwin64-x86_64-cc")

    	elseif (UNIX)
			set (configure_command "${source_tree}/config")
		else ()
			message (FATAL_ERROR "implement me")
		endif ()
		list (APPEND configure_command "--openssldir=${sanity.target.local}/ssl")
		list (APPEND configure_command "shared")
		execute_process(COMMAND ${configure_command} 
				    	WORKING_DIRECTORY ${build_dir}
				    	RESULT_VARIABLE res)
		if (res)
			sanity_join (cmd_line " " ${configure_command})
			message (FATAL_ERROR 
"${cmd_line}
error code : ${res}"
				)
		endif ()
		sanity_touch_flag (configure_flag)
	endif ()


	sanity_make_flag(make_depend_flag "target" "${package_name}" "make_depend")
	if (${configure_flag} IS_NEWER_THAN ${make_depend_flag})
		execute_process(COMMAND make depend 
					     WORKING_DIRECTORY ${build_dir}
					     RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name}")
		endif ()
		sanity_touch_flag(make_depend_flag)
	endif ()

	sanity_make_flag(make_flag "target" "${package_name}" "make")
	if (${make_depend_flag} IS_NEWER_THAN ${make_flag})
		execute_process(COMMAND make "-j${sanity.concurrency}"
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name} - error code ${res}")
		endif ()
		execute_process(COMMAND make install
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to install ${package_name} - error code ${res}")
		endif ()
		sanity_touch_flag (make_flag)
	endif ()

	set (OPENSSL_FOUND TRUE)
	set (OPENSSL_INCLUDE_DIR "${sanity.target.local}/ssl/include")
	set (OPENSSL_CRYPTO_LIBRARY "${sanity.target.local}/ssl/lib/libcrypto.a")
	set (OPENSSL_SSL_LIBRARY "${sanity.target.local}/ssl/lib/libssl.a")
	set (OPENSSL_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY} ${OPENSSL_SSL_LIBRARY})
	set (OPENSSL_VERSION "${version}")

	find_package(Threads)

	if (NOT TARGET sanity::crypto)
		add_library(sanity::crypto INTERFACE IMPORTED GLOBAL)
		target_link_libraries(sanity::crypto INTERFACE 
			${OPENSSL_CRYPTO_LIBRARY} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS})
		set_property(TARGET sanity::crypto
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_INCLUDE_DIR})
	endif ()

	if (NOT TARGET sanity::openssl)
		add_library(sanity::openssl INTERFACE IMPORTED GLOBAL)
		target_link_libraries(sanity::openssl INTERFACE 
			${OPENSSL_SSL_LIBRARY} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS} sanity::crypto)
		set_property(TARGET sanity::openssl
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_INCLUDE_DIR})
	endif ()

	set (sanity.require_openssl.complete TRUE)

	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
						  CMAKE_USE_SPROC_INIT
						  CMAKE_USE_WIN32_THREADS_INIT
						  CMAKE_USE_PTHREADS_INIT
						  CMAKE_HP_PTHREADS_INIT
						  CMAKE_DL_LIBS
							OPENSSL_FOUND
							OPENSSL_INCLUDE_DIR
							OPENSSL_CRYPTO_LIBRARY
							OPENSSL_SSL_LIBRARY
							OPENSSL_LIBRARIES
							OPENSSL_VERSION
						  sanity.require_openssl.complete)

endfunction ()
