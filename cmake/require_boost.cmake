include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

# \brief turn a version string into a boost package name
# \brief @param outvar is the name of the variable to populate
# \brief @param VERSION <version> is the version of boost
# \brief @returns outvar
function (boost_make_package_name outvar)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})

    if (NOT outvar OR NOT ARG_VERSION)
        message (FATAL_ERROR "boost_make_package_name(${ARGN})")
    endif ()

    string(REPLACE "." "_" boost_version_name "${version}")
    set (package_name "boost_${boost_version_name}")
    set (${outvar} "${package_name}" PARENT_SCOPE)
endfunction ()

# \brief download a version of the archive if necessary
# \brief @param outvar is the name of the variable to populate with the path to the archive
# \brief @param VERSION <version> is the version of boost
# \brief @returns outvar
function (boost_acquire_archive outvar)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})

    if (NOT outvar OR NOT ARG_VERSION)
        message (FATAL_ERROR "boost_acquire_archive(${ARGN})")
    endif ()

    set (version_details_1.60.0 "https://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.bz2/download"
                                "${sanity.source.cache.archive}/boost_1_60_0.tar.bz2"
                                MD5
                                65a840e1a0b13a558ff19eeb2c4f0cbe)
    set (version_details_1.60.0 "https://sourceforge.net/projects/boost/files/boost/1.61.0/boost_1_61_0.tar.bz2/download"
                                "${sanity.source.cache.archive}/boost_1_61_0.tar.bz2"
                                MD5
                                6095876341956f65f9d35939ccea1a9f)

    set(version_details_tuple "version_details_${ARG_VERSION}")
    list (LENGTH "${version_details_tuple}" check)
    if (NOT check EQUAL 4)
        message (STATUS "invalid version: function (boost_acquire_archive ${ARGN})")
        message (FATAL_ERROR "${version_details_tuple}=${${version_details_tuple}}")
    endif ()

    list (GET "${version_details_tuple}" 0 url)
    list (GET "${version_details_tuple}" 1 archive_path)
    list (GET "${version_details_tuple}" 2 hash_method)
    list (GET "${version_details_tuple}" 3 expected_hash)

    file ("${hash_method}" "${archive_path}" current_hash)
    if (NOT current_hash STREQUAL expected_hash)
        message (STATUS "downloading archive from [${url}] to [${archive_path}]") 
        sanity_download(URL "${url}"
                        PATH "${archive_path}"
                        HASH_METHOD "${hash_method}"
                        HASH_EXPECTED ${expected_hash}
                        ERROR_RESULT err)
        if (err)
            message (FATAL_ERROR "download error: ${res}")
        endif ()
    endif ()

    set (${outvar} "${archive_path}" PARENT_SCOPE)

endfunction ()

function (boost_bootstrap)
endfunction ()

function (sanity_require_boost)
	set(options)
	set(oneValueArgs VERSION)
	set(multiValueArgs COMPONENTS)
	cmake_parse_arguments(ARG "${options}" 
                		  "${oneValueArgs}" "${multiValueArgs}"
				  ${ARGN})

	set (versions 1.60.0)
	sanity_back(versions latest_version)
	sanity_deduce_version(${ARG_VERSION} versions boost version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

        boost_make_package_name(package_name VERSION ${version})
        boost_acquire_archive(source_gz VERSION ${version})

	if (sanity.require_boost.complete)
		return ()
	endif ()

	#
	# prerequisites
	#
	sanity_require (LIBRARY openssl VERSION any)
	sanity_require (LIBRARY icu VERSION any)

	set (source_url "https://sourceforge.net/projects/boost/files/boost/${version}/${package_name}.tar.bz2/download")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.bz2")

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
		message (STATUS "boost install b2 args: ${arg_string}")
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
        if (NOT TARGET boost)
            add_library(boost INTERFACE IMPORTED GLOBAL)
            target_link_libraries(boost INTERFACE 
                    ${CMAKE_THREAD_LIBS_INIT} 
                    ${CMAKE_DL_LIBS})
            set_target_properties(boost PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})
        endif ()


	file (GLOB Boost_LIBRARIES "${sanity.target.local}/lib/libboost_*.a")
	set (names_to_propagate )
	foreach (libpath IN LISTS Boost_LIBRARIES)
		get_filename_component (libname ${libpath} NAME_WE)
		string (SUBSTRING "${libname}" 9 -1 component)
		string (SUBSTRING "${libname}" 3 -1 target_name)
		string (TOUPPER ${component} upper_component)
		set (Boost_XXX_FOUND "Boost_${upper_component}_FOUND")
		set (Boost_XXX_LIBRARY "Boost_${upper_component}_LIBRARY")
		set (${Boost_XXX_FOUND} TRUE)
		set (${Boost_XXX_LIBRARY} ${libpath})
		list (APPEND names_to_propagate ${Boost_XXX_FOUND} ${Boost_XXX_LIBRARY})
                set(sanity_target "boost::${component}")
                if (NOT TARGET ${sanity_target})
                    add_library(${sanity_target} INTERFACE IMPORTED GLOBAL)
                    target_link_libraries(${sanity_target} 
                                            INTERFACE ${libpath} boost)
                endif ()
                if (NOT TARGET ${target_name})
                    add_library(${target_name} INTERFACE IMPORTED GLOBAL)
                    target_link_libraries(${target_name} 
                                            INTERFACE ${libpath} boost)
                endif()
				if (NOT TARGET "sanity::${sanity_target}")
					add_library ("sanity::${sanity_target}" IMPORTED INTERFACE GLOBAL)
					target_link_libraries("sanity::${sanity_target}" INTERFACE ${sanity_target})
				endif()
	endforeach ()
	if (NOT TARGET sanity::boost)
		add_library (sanity::boost IMPORTED INTERFACE GLOBAL)
		target_link_libraries (sanity::boost INTERFACE boost)
	endif ()
        target_link_libraries(boost::thread 
                                INTERFACE boost::system)
        # etc...
	set (BOOST_ROOT ${sanity.target.local})
	set (BOOST_INCLUDEDIR ${sanity.target.local}/include)
	set (BOOST_LIBRARYDIR ${sanity.target.local}/lib)
        set (Boost_NO_SYSTEM_PATHS ON)
        set (Boost_USE_STATIC_LIBS ON)


	set (sanity.require_boost.complete TRUE)

	sanity_propagate_vars(Boost_FOUND 
                                Boost_INCLUDE_DIRS
                                Boost_LIBRARY_DIRS
                                Boost_LIBRARIES
                                BOOST_ROOT
                                BOOST_INCLUDEDIR
                                BOOST_LIBRARYDIR
                                Boost_NO_SYSTEM_PATHS
                                Boost_USE_STATIC_LIBS
                                sanity.require_boost.complete
                                ${names_to_propagate})


endfunction ()
