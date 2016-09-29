#https://www.libsdl.org/release/SDL-1.2.15.tar.gz

include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_sdl given_version)

	set (library sdl)
	set (library_upper SDL)
	set (versions 1.2.15)
	set (hashes)
	list (APPEND hashes "SHA256;d6d316a793e5e348155f0dd93b979798933fb98aa1edebcc108829d6474aad00")
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions ${library} version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	set (complete_flag "sanity.require_${library}.complete")
	if (${${complete_flag}})
		return ()
	endif ()

	set (package_name "${library_upper}-${version}")
	set (flag_base ${sanity.source.cache.flags}/)
	set (source_url "https://www.libsdl.org/release/${package_name}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (build_dir ${sanity.target.build}/${package_name})
	set (untar_root "${sanity.source.cache.source}")
	set (source_tree "${untar_root}/${package_name}")
	math (EXPR hash_type_index "${version_index} * 2")
	math (EXPR hash_value_index "${hash_type_index} + 1")
	list (GET hashes ${hash_type_index} hash_method)
	list (GET hashes ${hash_value_index} source_hash)

	if (NOT EXISTS ${source_url})
		sanity_download(URL ${source_url} PATH ${source_gz}
						HASH_METHOD ${hash_method}
						HASH_EXPECTED ${source_hash}
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
	sanity_make_flag(configure_flag "target" "${package_name}" "configure")

	if (NOT EXISTS ${source_tree} OR NOT EXISTS ${untar_flag})
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
		)
		file (MAKE_DIRECTORY ${build_dir})
		set (configure_command "${source_tree}/configure")
		list (APPEND configure_command "--prefix=${sanity.target.local}")
		list (APPEND configure_command "--disable-shared")
		list (APPEND configure_command "--enable-static=yes")
		list (APPEND configure_command "--disable-video-x11")
		list (APPEND configure_command "--disable-video-cocoa")
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

	find_package(Threads)
	set(component_names SDL_INCLUDE_DIRS SDL_LIBRARY SDL_LIBRARY_MAIN SDL_FOUND SDL_VERSION_STRING)
	set(SDL_INCLUDE_DIRS "${sanity.target.local}/include")
	set(SDL_LIBRARY "${sanity.target.local}/lib/libSDL.a")
	set(SDL_LIBRARY_MAIN "${sanity.target.local}/lib/libSDLmain.a")
	set(SDL_FOUND True)
	set(SDL_VERSION_STRING "${version}")

	if (NOT TARGET sanity::sdl)
		add_library(sanity::sdl INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::sdl 
                                INTERFACE ${SDL_LIBRARY})
		set_property(TARGET sanity::sdl
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${SDL_INCLUDE_DIRS})

		add_library(sanity::sdl_main INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::sdl_main 
                                INTERFACE ${SDL_LIBRARY_MAIN} ${SDL_LIBRARY})
		set_property(TARGET sanity::sdl_main
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${SDL_INCLUDE_DIRS})
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
