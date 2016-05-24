# http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-src.tgz

include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_icu given_version)

	set (library icu)
	set (versions 57.1)
	set (hashes)
	list (APPEND hashes "MD5;976734806026a4ef8bdd17937c8898b9")
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions ${library} version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	set (complete_flag "sanity.require_${library}.complete")
	if (${${complete_flag}})
		return ()
	endif ()

	set (package_name "icu-${version}")
	string(REPLACE "." "_" web_version "${version}")
	set (source_url "http://download.icu-project.org/files/icu4c/${version}/icu4c-${web_version}-src.tgz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	# source must be configured in its own tree :(
	set (untar_root "${sanity.target.local.source}")
	set (source_tree "${untar_root}/${package_name}")
	set (build_dir ${sanity.target.build}/${package_name})
	math (EXPR hash_type_index "${version_index} * 2")
	math (EXPR hash_value_index "${hash_type_index} + 1")
	list (GET hashes ${hash_type_index} hash_method)
	list (GET hashes ${hash_value_index} source_hash)

	if (NOT EXISTS ${source_gz})
		sanity_download(URL "${source_url}" PATH "${source_gz}"
						HASH_METHOD "${hash_method}"
						HASH_EXPECTED "${source_hash}"
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	sanity_make_flag(untar_flag "target" "${package_name}" "untar")
	sanity_make_flag(configure_flag "target" "${package_name}" "configure")

	if (NOT EXISTS ${source_tree})
    	execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
						WORKING_DIRECTORY ${untar_root}
						RESULT_VARIABLE res)
	    if (res)
	    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
	    endif ()
	    if (EXISTS "${untar_root}/icu")
	    	file(RENAME "${untar_root}/icu" "${source_tree}")
	    else ()
	    	message (FATAL_ERROR "don't know where ${source_gz} unzips to. please check.")
	    endif ()
		sanity_touch_flag(untar_flag)
	endif()

	if (${untar_flag} IS_NEWER_THAN ${configure_flag}
		OR ${untar_flag} IS_NEWER_THAN ${build_dir}
#		OR ${build_dir} IS_NEWER_THAN ${CMAKE_CURRENT_LIST_FILE}
		)
		file (MAKE_DIRECTORY ${build_dir})
		set (configure_command "${source_tree}/source/runConfigureICU")
		if (APPLE)
			list (APPEND configure_command "MacOSX")
    	elseif (UNIX)
			list (APPEND configure_command "Linux")
		else ()
			message (FATAL_ERROR "implement me")
		endif ()
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--enable-shared=no")
		list (APPEND configure_command "--enable-static=yes"
										"--enable-tools=yes"
										"--enable-tests=no"
										"--enable-samples=no")
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

	set(use_cxx_flags "$ENV{CXXFLAGS}")
	string(APPEND use_cxx_flags " -std=c++11")

	sanity_make_flag(clean_flag "target" "${package_name}" "clean")
	sanity_make_flag(make_flag "target" "${package_name}" "make")

	if (${configure_flag} IS_NEWER_THAN ${clean_flag})
		file (MAKE_DIRECTORY "${build_dir}")
		execute_process(COMMAND make "-j${sanity.concurrency}" clean
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(clean_flag)
	endif ()


	if (${clean_flag} IS_NEWER_THAN ${make_flag} OR NOT EXISTS ${make_flag})
		set(cxxflags_save "$ENV{CXXFLAGS}")
		set($ENV{CXX_FLAGS} "${use_cxx_flags}")
		execute_process(COMMAND make "-j${sanity.concurrency}"
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		set($ENV{CXXFLAGS} "${cxxflags_save}")
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

	set (ICU_FOUND TRUE)
	set (ICU_INCLUDE_DIRS "${sanity.target.local}/include")
	file (GLOB ICU_LIBRARIES "${sanity.target.local}/libicu*.*")
	set (ICU_VERSION "${version}")

	find_package(Threads)
	set(component_names ICU_FOUND ICU_INCLUDE_DIRS ICU_LIBRARIES ICU_VERSION)
	if (NOT TARGET sanity::icu)
		add_library(sanity::icu INTERFACE IMPORTED GLOBAL)
		set_property(TARGET sanity::icu
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${ICU_INCLUDE_DIRS})
	endif ()
	foreach (file IN LISTS ICU_LIBRARIES)
		get_filename_component(lib_root ${file} NAME_WE)
		string(SUBSTRING "${lib_root}" 6 -1 component)

		set (sanity_lib "sanity::icu::${component}")
		if (NOT TARGET "${sanity_lib}")
			add_library("${sanity_lib}" INTERFACE IMPORTED GLOBAL)
			target_link_libraries("${sanity_lib}" "${file}")
			set_property(TARGET sanity::icu
				APPEND 
				PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${ICU_INCLUDE_DIRS})
			if (NOT "${component}" STREQUAL "test")
				target_link_libraries(sanity::icu "${sanity_lib}")
			endif ()
		endif ()
		string(TOUPPER "${component}" upper_component)
		set (component_name "ICU_${upper_component}_FOUND")
		list(APPEND component_names "${component_name}")
		set (${component_name} TRUE)
	endforeach()

	set (${complete_flag} TRUE)

	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
						  CMAKE_USE_SPROC_INIT
						  CMAKE_USE_WIN32_THREADS_INIT
						  CMAKE_USE_PTHREADS_INIT
						  CMAKE_HP_PTHREADS_INIT
						  CMAKE_DL_LIBS
						  ${component_names}
						  ${complete_flag})

endfunction ()
