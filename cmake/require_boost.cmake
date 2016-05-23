include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

function (sanity_require_boost given_version)

	set (versions 1.61.0)
	set (hashes 6095876341956f65f9d35939ccea1a9f)
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions boost version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	if (sanity.require_boost.complete)
		return ()
	endif ()

	#
	# prerequisites
	#
	sanity_require (LIBRARY openssl VERSION any)
	sanity_require (LIBRARY icu VERSION any)

	string(REPLACE "." "_" boost_version_name "${version}")
	set (package_name "boost_${boost_version_name}")
	set (flag_base ${sanity.source.cache.flags}/)
	set (source_url "https://sourceforge.net/projects/boost/files/boost/${version}/${package_name}.tar.bz2/download")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.bz2")
	list (GET hashes ${version_index} source_hash)

	file (DOWNLOAD ${source_url} 
		 ${source_gz} 
		 SHOW_PROGRESS
	     EXPECTED_HASH MD5=${source_hash})

	set (source_tree "${sanity.target.local.source}/${package_name}")

	sanity_make_flag(untar_flag "target" "${package_name}" "untar")

	if (${source_gz} IS_NEWER_THAN ${untar_flag}
		OR ${source_gz} IS_NEWER_THAN ${source_tree})
		execute_process(
    		COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    		WORKING_DIRECTORY ${sanity.target.local.source}
    		RESULT_VARIABLE res)
		if (res)
			message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		endif ()
		sanity_touch_flag(untar_flag)
	endif()

	# TODO : logic here depending on the target type
	if (APPLE AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND version STREQUAL "1.61.0")
		set (stdcpp.version "c++11")
	else ()
		set (stdcpp.version "c++14")
	endif ()

	set (build_dir ${source_tree})
	set (build_dir "${sanity.target.build}/${package_name}")
	
	sanity_make_flag(bootstrap_flag "target" "${package_name}" "bootstrap")
	if (${untar_flag} IS_NEWER_THAN ${bootstrap_flag})
		execute_process(COMMAND ./bootstrap.sh --prefix=${sanity.target.local}
						WORKING_DIRECTORY ${source_tree}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "./bootstrap.sh --prefix=${sanity.target.local} : ${res}")
		endif ()
		sanity_touch_flag(bootstrap_flag)
	endif ()

	sanity_make_flag(build_boost_flag "target" "${package_name}" "build")
	find_package(Threads)

	if (${bootstrap_flag} IS_NEWER_THAN ${build_boost_flag})
		file(MAKE_DIRECTORY ${build_dir})
		set (b2_args)
		list (APPEND b2_args "--build-dir=${build_dir}"
							"variant=release" 
							"link=static" 
							"threading=multi" 
							"runtime-link=shared" 
							"cxxflags=-std=${stdcpp.version}"
							"-j${sanity.concurrency}"
							"-sICU_PATH=${sanity.target.local}")
		if (APPLE)
		elseif (UNIX)
			list (APPEND b2_args "linkflags=-lpthread -ldl")
		endif ()
		sanity_join(arg_string " " ${b2_args})
		message (STATUS "args: ${b2_args}")
		execute_process(COMMAND ./b2 
						${b2_args}
						install
						WORKING_DIRECTORY ${source_tree}
          				ERROR_VARIABLE err_stream
						RESULT_VARIABLE res)
		if (res)
			message (STATUS "build failure: ${res}")
			set (error_path "${sanity.target.local}/errors")
			file (MAKE_DIRECTORY "${error_path}")
			message (STATUS "writing boost build errors to ${error_path}/boost.err")
			file (WRITE "${error_path}/boost.err" "${err_stream}")
		endif ()
		sanity_touch_flag (build_boost_flag)
	endif ()

#
# make the targets
#
	set (Boost_FOUND TRUE)
	set (Boost_INCLUDE_DIRS ${sanity.target.local}/include)
	set (Boost_LIBRARY_DIRS ${sanity.target.local}/lib)
	find_package(Threads)
	add_library(boost INTERFACE IMPORTED GLOBAL)
	target_link_libraries(boost INTERFACE 
		${CMAKE_THREAD_LIBS_INIT} 
		${CMAKE_DL_LIBS})
	set_target_properties(boost PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})

	file (GLOB Boost_LIBRARIES "${sanity.target.local}/lib/libboost_*.a")
	set (names_to_propagate )
	foreach (libpath IN LISTS Boost_LIBRARIES)
		get_filename_component (libname ${libpath} NAME_WE)
		string (SUBSTRING "${libname}" 9 -1 component)
		string (SUBSTRING "${libname}" 3 -1 target_name)
#		message (STATUS "boost component   : ${component}")
#		message (STATUS "boost target_name : ${target_name}")
		string (TOUPPER ${component} upper_component)
		set (Boost_XXX_FOUND "Boost_${upper_component}_FOUND")
		set (Boost_XXX_LIBRARY "Boost_${upper_component}_LIBRARY")
		set (${Boost_XXX_FOUND} TRUE)
		set (${Boost_XXX_LIBRARY} ${libpath})
		list (APPEND names_to_propagate ${Boost_XXX_FOUND} ${Boost_XXX_LIBRARY})
		add_library(${target_name} INTERFACE IMPORTED GLOBAL)
		target_link_libraries(${target_name} INTERFACE ${libpath} boost)
	endforeach ()
	target_link_libraries(boost_thread INTERFACE boost_system)
	set (Boost_ROOT ${sanity.target.local})


	set (sanity.require_boost.complete TRUE)

	sanity_propagate_vars(Boost_FOUND 
						  Boost_INCLUDE_DIRS
						  Boost_LIBRARY_DIRS
						  Boost_LIBRARIES
						  Boost_ROOT
						  sanity.require_boost.complete
						  ${names_to_propagate})


endfunction ()
