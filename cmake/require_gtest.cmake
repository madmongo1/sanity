function (sanity_require_gtest version)
	set (versions 1.7.0)
	set (hashes 4ff6353b2560df0afecfbda3b2763847)
	sanity_back(versions latest_version)

#
# recursion check
#
	if (version STREQUAL "latest")
		sanity_require_gtest(${latest_version})
		sanity_propagate_vars ()
		return ()
	endif ()

#
# preconditions
#
	if (version VERSION_LESS latest_version)
		message (FATAL_ERROR "sanity_require_gtest requesting version ${version} but latest available is ${latest_version}")
	endif ()

	if (NOT sanity.gtest.version)
		set (version "${latest_version}")
		set(sanity.gtest.version ${version} CACHE STRING "version of gtest selected")
	endif ()

	if (sanity.gtest.version VERSION_LESS version)
		message (FATAL_ERROR "gtest version ${version} specified but lower version ${sanity.gtest.version} available")
	endif()

#
# re-entry check
#
	if (sanity.require_gtest.complete)
		return ()
	endif ()

#
# find index of this version in version list
# and set up dependent variables
#
	list (FIND versions "${sanity.gtest.version}" version_index)
	if (version_index LESS 0)
		message (FATAL_ERROR "unknown version of gtest: ${sanity.gtest.version}")
	endif ()

	list (GET hashes ${version_index} source_hash)

# download source

	set (version_string "release-${version}")
	set (package_name "googletest-${version_string}")
#	set (source_url "https://github.com/google/googletest/archive/release-${version}.tar.gz")
	set (source_url "https://codeload.github.com/google/googletest/tar.gz/${version_string}")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (source_tree "${sanity.source.cache.source}/${package_name}")

	message (STATUS "downloading : ${source_url}")
	message (STATUS "destination : ${source_gz}")
	file(DOWNLOAD ${source_url} 
		${source_gz} 
		SHOW_PROGRESS
		EXPECTED_HASH MD5=${source_hash})
	
# maybe untar
	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	set (need_untar FALSE)
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}")
		set (need_untar TRUE)
	endif ()
	if ("${source_gz}" IS_NEWER_THAN "${build_dir}")
		set (need_untar TRUE)
	endif ()
	if (need_untar)
		execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    					WORKING_DIRECTORY ${sanity.source.cache.source}
    					RESULT_VARIABLE res)
		if (res)
		    message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		endif ()
		sanity_touch_flag(untar_flag)
	endif()

#
# maybe configure the build
#
	find_package(Threads)
	set (build_dir ${sanity.target.build}/${package_name})
	sanity_make_flag(run_cmake_flag "target" "${package_name}" "cmake")
	if ("${untar_flag}" IS_NEWER_THAN "${run_cmake_flag}")
		file(MAKE_DIRECTORY ${build_dir})
		set (args)
		set (prefix_paths ${CMAKE_PREFIX_PATH})
		list (APPEND prefix_paths "${sanity.target.local}")
		list (REMOVE_DUPLICATES prefix_paths)
		sanity_join(prefix_paths_string ";" ${prefix_paths})
		list(APPEND args 	   			
			"-DCMAKE_PREFIX_PATH=${prefix_paths_string}"
			"-DCMAKE_INSTALL_PREFIX=${sanity.target.local}"
			"-DGTEST_USE_OWN_TR1_TUPLE=1")
		execute_process(
	   		COMMAND ${CMAKE_COMMAND}
	   		${args}
			${source_tree}
	   		WORKING_DIRECTORY ${build_dir}
 	 		RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
		endif ()
		sanity_touch_flag(run_cmake_flag)
	endif ()

#
# maybe build the library
#
	sanity_make_flag(run_make_flag "target" "${package_name}" "make")
	if ("${run_cmake_flag}" IS_NEWER_THAN "${run_make_flag}")
		execute_process(COMMAND make -j4 
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to build mysqlcppconn - ${res}") 
		endif ()
		sanity_touch_flag(run_make_flag)
	endif ()

	set (GTest_Found TRUE)
	set (GTest_INCLUDE_DIRS "${source_tree}/include")
	set (GTest_LIBRARIES "${build_dir}/libgtest.a")
	set (GTest_MAIN_LIBRARIES "${build_dir}/libgtest_main.a" "${GTest_LIBARIES}")
    set (GTest_LIBRARY_DIRS "${build_dir}")

	find_package(Threads)
	if (NOT TARGET gtest)
		add_library(gtest INTERFACE IMPORTED GLOBAL)
		target_link_libraries(gtest INTERFACE 
			${GTest_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
			${CMAKE_DL_LIBS})
		set_target_properties(gtest PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${GTest_INCLUDE_DIRS})
	endif ()

	if (NOT TARGET gtest_main)
		add_library(gtest_main INTERFACE IMPORTED GLOBAL)
		target_link_libraries(gtest_main INTERFACE ${GTest_MAIN_LIBRARIES} gtest)
	endif ()
	
	set (sanity.require_gtest.complete TRUE)
	sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
							CMAKE_USE_SPROC_INIT
							CMAKE_USE_WIN32_THREADS_INIT
							CMAKE_USE_PTHREADS_INIT
							CMAKE_HP_PTHREADS_INIT
							CMAKE_DL_LIBS
							GTest_Found
							GTest_INCLUDE_DIRS 
							GTest_LIBRARIES
							GTest_MAIN_LIBRARIES
							GTest_LIBRARY_DIRS 
							sanity.require_gtest.complete)

endfunction ()
