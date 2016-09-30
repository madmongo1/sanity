#http://download.osgeo.org/libtiff/tiff-4.0.6.tar.gz

include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_tiff given_version)

	set (library tiff)
	set (versions 4.0.6)
	set (hashes)
	list (APPEND hashes "MD5;d1d2e940dea0b5ad435f21f03d96dd72")
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions ${library} version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	set (complete_flag "sanity.require_${library}.complete")
	if (${${complete_flag}})
		return ()
	endif ()

	sanity_require(LIBRARY jpeg VERSION any)

	set (package_name "${library}-${version}")
	set (source_url "http://download.osgeo.org/libtiff/tiff-${version}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (untar_root "${sanity.source.cache.source}")
	set (source_tree "${untar_root}/${package_name}")
	set (build_dir ${sanity.target.build}/${package_name})
	math (EXPR hash_type_index "${version_index} * 2")
	math (EXPR hash_value_index "${hash_type_index} + 1")
	list (GET hashes ${hash_type_index} hash_method)
	list (GET hashes ${hash_value_index} source_hash)

	message(STATUS "building library ${library}")
	sanity_dump_n(package_name source_url source_gz untar_root source_tree build_dir)

	if (NOT EXISTS ${source_gz})
		sanity_download(URL "${source_url}" PATH "${source_gz}"
						HASH_METHOD "${hash_method}"
						HASH_EXPECTED "${source_hash}"
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	sanity_make_flag(configure_flag "target" "${package_name}" "configure")

	if (NOT EXISTS ${source_tree})
    	execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
						WORKING_DIRECTORY ${untar_root}
						RESULT_VARIABLE res)
	    if (res)
	    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
	    endif ()
		sanity_touch_flag(untar_flag)
	endif()

	if (${untar_flag} IS_NEWER_THAN ${configure_flag}
		OR ${untar_flag} IS_NEWER_THAN ${build_dir}
#		OR ${build_dir} IS_NEWER_THAN ${CMAKE_CURRENT_LIST_FILE}
		)
		file (MAKE_DIRECTORY ${build_dir})
		set (configure_command "${source_tree}/configure")
		if (APPLE)
    	elseif (UNIX)
		else ()
		endif ()
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--disable-shared")
		list (APPEND configure_command "--enable-static=yes")
		list (APPEND configure_command "--with-jpeg-include-dir=${sanity.target.local}/include")		
		list (APPEND configure_command "--with-jpeg-lib-dir=${sanity.target.local}/lib")
		
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

	sanity_make_flag(clean_flag "target" "${package_name}" "clean")
	sanity_make_flag(make_flag "target" "${package_name}" "make")

	if (${configure_flag} IS_NEWER_THAN ${clean_flag})
		file (MAKE_DIRECTORY "${build_dir}")
		execute_process(COMMAND make "-j${sanity.concurrency}" clean
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(clean_flag)
	endif ()


	if (${clean_flag} IS_NEWER_THAN ${make_flag} OR NOT EXISTS ${make_flag})
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

	set (TIFF_FOUND TRUE)
	set (TIFF_INCLUDE_DIR "${sanity.target.local}/include")
	set (TIFF_LIBRARIES ${sanity.target.local}/libtiffxx.a ${sanity.target.local}/libtiff.a)
	set (TIFF_LIBRARY "${sanity.target.local}/libtiff.a")
	set (TIFF_VERSION "${version}")

	set(component_names TIFF_FOUND TIFF_INCLUDE_DIR TIFF_LIBRARIES TIFF_LIBRARY TIFF_VERSION)
	if (NOT TARGET sanity::tiff)
		add_library(sanity::tiff INTERFACE IMPORTED GLOBAL )
		target_link_libraries(sanity::tiff INTERFACE ${TIFF_LIBRARIES})
		set_property(TARGET sanity::tiff
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${TIFF_INCLUDE_DIRS})
	endif ()

	set (${complete_flag} TRUE)

	sanity_propagate_vars(${complete_flag})

endfunction ()
