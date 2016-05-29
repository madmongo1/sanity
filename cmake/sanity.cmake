cmake_minimum_required(VERSION 3.5)
set (sanity.constant.this.version 1)


if (sanity.version)
	if (sanity.version VERSION_LESS sanity.constant.this.version)
		message (FATAL_ERROR 
				 "Sanity version ${sanity.version} in outer project. This is version ${sanity.constant.this.version} here: ${CMAKE_CURRENT_LIST_FILE}")
	endif ()
	return ()
else ()
	set (sanity.version "1")
	set (sanity.root ${CMAKE_CURRENT_LIST_DIR} CACHE PATH "Where the sanity scripts are located")
endif ()

if (APPLE)
	include ("${CMAKE_CURRENT_LIST_DIR}/apple_install_command_line_tools.cmake")
	include ("${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_darwin_toolset.cmake")
	sanity_deduce_darwin_toolset()
endif ()

#
# concurrency
#
set (sanity.concurrency 4)
if (CMAKE_HOST_APPLE)
	execute_process(COMMAND sysctl -n hw.ncpu 
					RESULT_VARIABLE err 
					OUTPUT_VARIABLE cout
					OUTPUT_STRIP_TRAILING_WHITESPACE)
	if (NOT err AND ${cout} GREATER 0)
		set (sanity.concurrency ${cout})
	endif ()
elseif (${CMAKE_HOST_SYSTEM_NAME} MATCHES "Linux")
	execute_process(COMMAND cat /proc/cpuinfo 
					COMMAND grep processor
					COMMAND wc -l
					OUTPUT_VARIABLE cout
					OUTPUT_STRIP_TRAILING_WHITESPACE)
	if (NOT err AND ${cout} GREATER 0)
		set (sanity.concurrency ${cout})
	endif ()
endif ()

# set up location variables for all future sanity builds

if (NOT sanity.source.cache)
	set (sanity.source.cache "$ENV{HOME}/.sanity-cache" CACHE PATH "cache directory for sanity downloads")
endif ()
file(MAKE_DIRECTORY ${sanity.source.cache})

if (NOT sanity.source.cache.flags)
	set (sanity.source.cache.flags "${sanity.source.cache}/flags" CACHE PATH "cache directory for sanity downloads")
endif ()
file(MAKE_DIRECTORY ${sanity.source.cache.flags})

if (NOT sanity.source.cache.archive)
	set (sanity.source.cache.archive "${sanity.source.cache}/archive" CACHE PATH "cache directory for sanity downloads")
endif ()
file(MAKE_DIRECTORY ${sanity.source.cache.archive})

if (NOT sanity.source.cache.archive.source)
	set (sanity.source.cache.source "${sanity.source.cache}/src" CACHE PATH "cache directory for sanity downloads")
endif ()
file(MAKE_DIRECTORY ${sanity.source.cache.source})

if (NOT sanity.target.local)
	set (sanity.target.local "${CMAKE_CURRENT_BINARY_DIR}/target_local" CACHE PATH "the install path for files required by the target build")
endif ()
file(MAKE_DIRECTORY ${sanity.target.local})

if (NOT sanity.target.flags)
	set (sanity.target.flags "${CMAKE_CURRENT_BINARY_DIR}/target_flags" CACHE PATH "the flags path for processes required by the target build")
endif ()
file(MAKE_DIRECTORY ${sanity.target.flags})

if (NOT sanity.target.local.source)
	set (sanity.target.local.source "${sanity.target.local}/src" CACHE PATH "the src path for target builds if needed")
endif ()
file(MAKE_DIRECTORY ${sanity.target.local.source})

if (NOT sanity.target.build)
	set (sanity.target.build "${CMAKE_CURRENT_BINARY_DIR}/target_build" CACHE PATH "the build path for files required by the target build")
endif ()
file(MAKE_DIRECTORY ${sanity.target.build})

if (NOT sanity.host.local)
	set (sanity.host.local "${CMAKE_CURRENT_BINARY_DIR}/host_local" CACHE PATH "the install path for files required by the host build environemnt")
endif ()
file(MAKE_DIRECTORY ${sanity.host.local})

if (NOT sanity.host.flags)
	set (sanity.host.flags "${CMAKE_CURRENT_BINARY_DIR}/host_flags" CACHE PATH "flag files for the host build environment")
endif ()
file(MAKE_DIRECTORY ${sanity.host.flags})

if (NOT sanity.host.build)
	set (sanity.host.build "${CMAKE_CURRENT_BINARY_DIR}/host_build" CACHE PATH "the build path for files required by the host build environment")
endif ()
file(MAKE_DIRECTORY ${sanity.host.build})


function (sanity_join outvar separator)
	set (result)
	set (sep)
	foreach (item ${ARGN})
		string(CONCAT result "${result}" "${sep}" "${item}")
		set (sep "${separator}")
	endforeach ()
	set (${outvar} "${result}" PARENT_SCOPE)

endfunction ()

function (sanity_make_flag outvar flag_type)

	set (result )
	set (sep "${sanity.${flag_type}.flags}/")
	foreach (bit ${ARGN})
		string (CONCAT result "${result}" "${sep}" "${bit}")
		set (sep "-")
	endforeach ()
	set (${outvar} "${result}" PARENT_SCOPE)

endfunction ()

function (sanity_touch_flag flagname_name)
	set (flagname ${${flagname_name}})
	if (NOT flagname )
		message (FATAL_ERROR "sanity_touch_flag(${flagname}) : invalid flag")
	endif ()
	execute_process (COMMAND ${CMAKE_COMMAND} -E touch ${flagname} RESULT_VARIABLE res)
	if (res)
		message (FATAL_ERROR "error touching ${flagname} : ${res}")
	endif ()
endfunction ()

function (sanity_dump)
	message (STATUS "Sanity Settings")
	set (vars 	sanity.version sanity.source.cache sanity.source.cache.flags sanity.source.cache.archive
				sanity.source.cache.source sanity.target.local sanity.target.build sanity.host.local sanity.host.build
				sanity.target.flags sanity.concurrency)
	set (maxlen 0)
	foreach (name IN LISTS vars)
		string(LENGTH "${name}" thislen)
		if (thislen GREATER maxlen)
			set(maxlen ${thislen})
		endif ()
	endforeach ()
	foreach (name IN LISTS vars)
		set(namerep "${name}")
		string(LENGTH "${namerep}" thislen)
		while (thislen LESS maxlen)
		    string(CONCAT namerep "${namerep}" " ")
			string(LENGTH "${namerep}" thislen)
		endwhile()
		message ("    ${namerep} : ${${name}}")
	endforeach ()
endfunction ()

# return the last item in a LIST
function (sanity_back container_name outname)
	list (LENGTH ${container_name} len)
	if (len LESS 1)
		message (FATAL_ERROR "sanity_back (${container_name}) : list length is ${len}")
	endif ()
	math (EXPR index "${len} - 1")
	list (GET ${container_name} ${index} result)
	set (${outname} ${result} PARENT_SCOPE)
endfunction ()

function (sanity_list_to_string outvar delim)
	set (result)
	set (sep "")
	foreach (item ${ARGN})
		string(CONCAT result "${result}" "${sep}" "${item}")
		set(sep ", ")
	endforeach ()
    set(${outvar} "${result}" PARENT_SCOPE)
endfunction ()

macro (sanity_propagate_value)
#	message ("sanity_propagate_value (${ARGN})")
	set (_options)
	set (_oneValueArgs NAME)
	set (_multiValueArgs VALUE)
	cmake_parse_arguments("" "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (NOT _NAME OR NOT _VALUE)
		sanity_join(_arg_str " ")
		message (FATAL_ERROR "invalid arguments: ${ARGN}")
	endif ()

	set (${_NAME} "${_VALUE}")
	list (APPEND sanity.propagate.list ${_NAME})
	list (REMOVE_DUPLICATES sanity.propagate.list)

	set (${_NAME} "${${_NAME}}" PARENT_SCOPE)
	set (sanity.propagate.list "${sanity.propagate.list}" PARENT_SCOPE)
endmacro ()

macro (sanity_propagate_value_if)
#	message ("sanity_propagate_value (${ARGN})")
	set (_options)
	set (_oneValueArgs NAME)
	set (_multiValueArgs VALUE)
	cmake_parse_arguments("" "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	if (NOT _NAME)
            sanity_join(_arg_str " ")
            message (FATAL_ERROR "invalid arguments: ${ARGN}")
	endif ()
        if (_VALUE)
            set (${_NAME} "${_VALUE}")
            list (APPEND sanity.propagate.list ${_NAME})
            list (REMOVE_DUPLICATES sanity.propagate.list)

            set (${_NAME} "${${_NAME}}" PARENT_SCOPE)
            set (sanity.propagate.list "${sanity.propagate.list}" PARENT_SCOPE)
        endif ()
endmacro ()

macro (sanity_propagate_vars)
	foreach (var ${ARGN})
		list (APPEND sanity.propagate.list "${var}")
	endforeach()
	list (REMOVE_DUPLICATES sanity.propagate.list)

#	message (STATUS "propagating list : ${sanity.propagate.list}")
	set (sanity.propagate.list "${sanity.propagate.list}" PARENT_SCOPE)
	foreach (var IN LISTS sanity.propagate.list)
		set (${var} "${${var}}" PARENT_SCOPE)
#		message (STATUS "--set (${var} ${${var}} PARENT_SCOPE)")
	endforeach()
endmacro ()

function (sanity_require)
	set(options)
	set(oneValueArgs LIBRARY VERSION)
	set(multiValueArgs COMPONENTS)
	cmake_parse_arguments(SANITY_REQUIRE "${options}" 
						  "${oneValueArgs}" "${multiValueArgs}"
						  ${ARGN})

	if (NOT SANITY_REQUIRE_LIBRARY)
		message (FATAL_ERROR
				 "usage: sanity_require(LIBRARY <libname> VERSION <min-version>)")
	else ()
		set(libname ${SANITY_REQUIRE_LIBRARY})
	endif ()

	if (NOT SANITY_REQUIRE_VERSION)
		message (FATAL_ERROR "sanity_require() called with no VERSION")
	else ()
		set (version ${SANITY_REQUIRE_VERSION})
	endif ()

        # COMPONENTS is nullable
        set (components)
        if (SANITY_REQUIRE_COMPONENTS)
            set(components ${SANITY_REQUIRE_COMPONENTS})
        endif ()

	set (sanity.valid.libs 
		boost
		gtest 
		icu
		openssl
		protobuf
		mysql 
		mysqlcppcon)
	list (FIND sanity.valid.libs ${libname} 
		  name_index)
    if (name_index LESS 0)
        sanity_list_to_string(rep ", " ${sanity.valid.libs})
    	message (FATAL_ERROR "unknown required library: ${libname}. Valid libraries are: ${rep}")
    endif ()

    if (libname STREQUAL "boost")
    	sanity_require_boost (VERSION ${version} COMPONENTS ${components})
    endif ()

    if (libname STREQUAL "gtest")
    	sanity_require_gtest(${version})
    endif ()

    if (libname STREQUAL "icu")
    	sanity_require_icu(${version})
	endif ()

    if (libname STREQUAL "mysql")
    	sanity_require_mysql (${version})
    endif ()

    if (libname STREQUAL "mysqlcppcon")
    	sanity_require_mysqlcppcon (${version})
    endif ()

    if (libname STREQUAL "openssl")
    	sanity_require_openssl (${version})
    endif ()

    if (libname STREQUAL "protobuf")
    	sanity_require_protobuf (${version})
    endif ()

	sanity_propagate_vars()

endfunction()


include ("${CMAKE_CURRENT_LIST_DIR}/require_boost.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_gtest.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_icu.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_mysql.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_mysqlcppcon.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_openssl.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_protobuf.cmake")

sanity_dump ()

