#http://www.littlecms.com/1/lcms-1.19.tar.gz

include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_lcms given_version)

	set (library lcms)
	set (versions 1.19)
	set (hashes)
	list (APPEND hashes "MD5;8af94611baf20d9646c7c2c285859818")
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
	sanity_require(LIBRARY tiff VERSION any)

	set (package_name "${library}-${version}")
	set (source_url "http://www.littlecms.com/1/lcms-${version}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	# source must be configured in its own tree :(
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
	sanity_make_flag(patch_flag "source.cache" "${package_name}" "patch")
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

	if (NOT EXISTS ${untar_flag})
		sanity_touch_flag(untar_flag)
	endif ()

	if (${untar_flag} IS_NEWER_THAN ${patch_flag})
		if ("${version}" STREQUAL "1.19")
			set (patch_file "${sanity.root}/patch/${library}-${version}.patch")

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

	set(untar_newer FALSE)
	if (${patch_flag} IS_NEWER_THAN ${configure_flag})
		set(untar_newer TRUE)
	endif ()

	set(build_older FALSE)
	if (${patch_flag} IS_NEWER_THAN ${build_dir})
		set(build_older TRUE)
	endif ()

	if (untar_newer OR build_older)
		file (MAKE_DIRECTORY ${build_dir})
		set (configure_command "${source_tree}/configure")
		if (APPLE)
    	elseif (UNIX)
		else ()
		endif ()
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--disable-shared")
		list (APPEND configure_command "--enable-static=yes")
		list (APPEND configure_command "--without-PACKAGE")
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


	set (LCMS_FOUND TRUE)
	set (LCMS_INCLUDE_DIR "${sanity.target.local}/include")
	set (LCMS_LIBRARIES "${sanity.target.local}/liblcms.a")
	set (LCMS_LIBRARY "${sanity.target.local}/liblcms.a")
	set (LCMS_VERSION "${version}")

	set(component_names LCMS_FOUND LCMS_INCLUDE_DIR LCMS_LIBRARIES LCMS_LIBRARY LCMS_VERSION)
	if (NOT TARGET sanity::lcms)
		add_library(sanity::lcms INTERFACE IMPORTED GLOBAL)
		target_link_libraries(sanity::lcms INTERFACE ${LCMS_LIBRARIES})
		set_property(TARGET sanity::lcms
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${LCMS_INCLUDE_DIRS})
	endif ()

	set (${complete_flag} TRUE)

	sanity_propagate_vars(${complete_flag})

endfunction ()
