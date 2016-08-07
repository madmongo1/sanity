include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

#https://sourceforge.net/projects/asio/files/asio/1.11.0%20%28Development%29/asio-1.11.0.tar.bz2/download

function (sanity_require_asio given_version)

	set (library asio)
	set (versions 1.11.0)
	set (hashes)
	list (APPEND hashes "SHA1;fb2d900178d1c79379e1c1ec67760644da971ee4")
	list (APPEND urls "http://downloads.sourceforge.net/project/asio/asio/1.11.0%20%28Development%29/asio-1.11.0.tar.bz2?r=&ts=1470527030&use_mirror=heanet")
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
	list (GET urls ${version_index} source_url)
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.bz2")
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

	sanity_make_current_system_flag(configure_flag PACKAGE "${package_name}" FUNCTION "configure")

	if (${untar_flag} IS_NEWER_THAN ${configure_flag})
		file (MAKE_DIRECTORY ${build_dir})
		MESSAGE (STATUS "${package_name}: configuring")
		set (configure_command "${source_tree}/configure")
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--with-openssl=${sanity.target.local}/ssl")
		list (APPEND configure_command "--without-boost")
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

	sanity_make_current_system_flag(clean_flag PACKAGE "${package_name}" FUNCTION "clean")
	sanity_make_current_system_flag(make_flag PACKAGE "${package_name}" FUNCTION "make")


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
	set(component_names ASIO_INCLUDE_DIRS ASIO_LIBRARIES ASIO_FOUND ASIO_VERSION_STRING)
	set(ASIO_INCLUDE_DIRS "${sanity.target.local}/include")
	set(ASIO_LIBRARIES "${sanity.target.local}/lib/libldns.a")
	set(ASIO_FOUND True)
	set(ASIO_VERSION_STRING "${version}")

	if (NOT TARGET sanity::asio)
		add_library(sanity::asio INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::asio 
                                INTERFACE ${ASIO_LIBRARIES} ${OPENSSL_LIBRARIES})
		set_property(TARGET sanity::asio
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${asio_INCLUDE_DIRS} ${OPENSSL_INCLUDE_DIR})
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