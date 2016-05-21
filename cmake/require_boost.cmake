function (sanity_require_boost version)

    set (latest_version 1.61.0)
	set (versions 1.61.0)
	set (hashes 6095876341956f65f9d35939ccea1a9f)

	if (version STREQUAL "latest")
		sanity_require_boost (${latest_version})
		sanity_propagate_vars ()
		return()
	endif ()

	if (NOT sanity.boost.version)
		if (version VERSION_LESS latest_version)
			set (version ${latest_version})
		endif ()
		set(sanity.boost.version ${version} CACHE STRING "version of boost chosen")
	endif ()

	if (sanity.boost.version VERSION_LESS version)
		message (FATAL_ERROR "boost version ${version} specified but lower version ${sanity.boost.version} already built")
		return()
	endif()

	if (version VERSION_LESS sanity.boost.version)
		set (version "${sanity.boost.version}")
	endif ()


	list (FIND versions "${sanity.boost.version}" version_index)
	if (version_index LESS 0)
		message (FATAL_ERROR "unknown version of boost: ${sanity.boost.version}")
	endif ()

	if (sanity.boost.complete)
		return ()
	endif ()

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

	     if (NOT EXISTS ${source_tree})
	     	execute_process(
    			COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
    			WORKING_DIRECTORY ${sanity.target.local.source}
    			RESULT_VARIABLE res
		    	)
		    if (res)
		    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
		    endif ()
		 endif()

		 # TODO : logic here depending on the target type
		 if (APPLE AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND version STREQUAL "1.61.0")
		 	set (stdcpp.version "c++11")
		 else ()
		 	set (stdcpp.version "c++14")
		 endif ()


		set (build_dir ${source_tree})
		execute_process(COMMAND ./bootstrap.sh --prefix=${sanity.target.local}
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "./bootstrap.sh --prefix=${sanity.target.local} : ${res}")
		endif ()

		execute_process(COMMAND ./b2 variant=release link=static threading=multi 
								runtime-link=shared "cxxflags=-std=${stdcpp.version}"
								-j4 install
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "./b2 variant=release link=static threading=multi runtime-link=shared cxxflags=-std=${stdcpp.version}: ${res}")
		endif ()

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
			message (STATUS "boost component   : ${component}")
			message (STATUS "boost target_name : ${target_name}")
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
