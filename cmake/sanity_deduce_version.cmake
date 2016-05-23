if (sanity.function.sanity_deduce_version.included)
	return ()
endif ()
set (sanity.function.sanity_deduce_version.included TRUE)

function (sanity_deduce_version given_version versions_list_name component_name outversion outindex)

	unset (${outversion} PARENT_SCOPE)
	unset (${outindex} PARENT_SCOPE)

	if ("${given_version}" STREQUAL "latest")
		sanity_back(${versions_list_name} version)
	elseif ("${given_version}" STREQUAL "any")
		if (${${component_cache_version}})
			set (version "${${component_cache_version}}")
		else ()
			sanity_back(${versions_list_name} version)
		endif ()
	else ()
		set (version "${given_version}")
	endif ()

	list (FIND ${versions_list_name} ${version} index)
	if (${index} LESS 0)
		sanity_join(possible_versions " " ${${versions_list_name}})
		message (FATAL_ERROR "component ${component_name} requested non-existant version ${given_version}. Possible versions are ${possible_versions}")
	endif ()

	if (${${component_cache_version}})
		if ("${version}" VERSION_LESS "${${component_cache_version}}")
			message (FATAL_ERROR "component ${component_name} requires version ${given_version} but version ${${component_cache_version}} is cached")
		return ()
		endif()
	else ()
		set(${component_cache_version} "${version}" CACHE STRING "version of component ${component_name}")
	endif ()


	set (${outversion} "${version}" PARENT_SCOPE)
	set (${outindex} "${index}" PARENT_SCOPE)

endfunction ()
