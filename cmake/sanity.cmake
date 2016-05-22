cmake_minimum_required(VERSION 3.5)
set (sanity.constant.this.version 1)


if (sanity.version)
	if (sanity.version VERSION_LESS sanity.constant.this.version)
		message (FATAL_ERROR 
				 "Sanity version ${sanity.version} in outer project. This is version ${sanity.constant.this.version} here: ${CMAKE_CURRENT_LIST_FILE}")
	endif ()
else ()
	set (sanity.version "1" CACHE STRING "current sanity version - do not change")
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
				sanity.target.flags)
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

function (sanity_list_to_string outvar delim)
	set (result)
	set (sep "")
	foreach (item ${ARGN})
		string(CONCAT result "${result}" "${sep}" "${item}")
		set(sep ", ")
	endforeach ()
    set(${outvar} "${result}" PARENT_SCOPE)
endfunction()

macro (sanity_propagate_vars)
	foreach (var ${ARGN})
		list(FIND sanity.propagate.list ${var} index)
		if (index EQUAL -1)
			list (APPEND sanity.propagate.list ${var})
		endif ()
	endforeach()
	set (sanity.propagate.list ${sanity.propagate.list} PARENT_SCOPE)
#message(STATUS "------ ${sanity.propagate.list}")
	foreach (var IN LISTS sanity.propagate.list)
		set (${var} ${${var}} PARENT_SCOPE)
#message(STATUS "-------- ${var} = ${${var}}")
	endforeach()
endmacro()

function (sanity_require)
	set(options)
	set(oneValueArgs LIBRARY VERSION)
	set(multiValueArgs)
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

	set (sanity.valid.libs boost mysql mysqlcppcon)
	list (FIND sanity.valid.libs ${libname} 
		  name_index)
    if (name_index LESS 0)
        sanity_list_to_string(rep ", " ${sanity.valid.libs})
    	message (FATAL_ERROR "unknown required library: ${libname}. Valid libraries are: ${rep}")
    endif ()

    if (libname STREQUAL "mysql")
    	sanity_require_mysql (${version})
    endif ()

    if (libname STREQUAL "mysqlcppcon")
    	sanity_require_mysqlcppcon (${version})
    endif ()

    if (libname STREQUAL "boost")
    	sanity_require_boost (${version})
    endif ()

	sanity_propagate_vars()

endfunction()


include ("${CMAKE_CURRENT_LIST_DIR}/require_mysql.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_boost.cmake")
include ("${CMAKE_CURRENT_LIST_DIR}/require_mysqlcppcon.cmake")
