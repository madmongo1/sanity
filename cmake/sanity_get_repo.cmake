if (sanity.function.sanity_get_repo.included)
	return ()
endif ()
set (sanity.function.sanity_get_repo.included TRUE)


function(sanity_get_repo)

	set(options)
	set(oneValueArgs ORIGIN LIBRARY_NAME LIBRARY_VERSION REQUIRED_COMMIT CHECKOUT_FLAG)
	set(multiValueArgs)
	cmake_parse_arguments(SANITY_GET_REPO "${options}" 
						  "${oneValueArgs}" "${multiValueArgs}"
						  ${ARGN})

	set (master_repo_base "${sanity.source.cache}/git")

	if (NOT SANITY_GET_REPO_ORIGIN)
		message (FATAL_ERROR "ORIGIN not set")
	else ()
		set(origin "${SANITY_GET_REPO_ORIGIN}")
	endif ()

	if (NOT SANITY_GET_REPO_LIBRARY_NAME)
		message (FATAL_ERROR "LIBRARY_NAME not set")
	else ()
		set (library_name "${SANITY_GET_REPO_LIBRARY_NAME}")
		set (master_repo_name "${library_name}.git")
		set (master_repo "${master_repo_base}/${master_repo_name}")
	endif ()

	if (NOT SANITY_GET_REPO_LIBRARY_VERSION)
		message (FATAL_ERROR "LIBRARY_VERSION not set")
	else ()
		set (library_version "${SANITY_GET_REPO_LIBRARY_VERSION}")
		set (package_name "${library_name}-${library_version}")
	endif ()

	if (NOT SANITY_GET_REPO_REQUIRED_COMMIT)
		message (FATAL_ERROR "REQUIRED_COMMIT not set")
	else ()
		set (required_commit "${SANITY_GET_REPO_REQUIRED_COMMIT}")
	endif ()

	if (NOT SANITY_GET_REPO_CHECKOUT_FLAG)
		message (FATAL_ERROR "CHECKOUT_FLAG not set")
	else ()
		set (checkout_flag_name "${SANITY_GET_REPO_CHECKOUT_FLAG}")
	endif ()


	
	if (NOT EXISTS "${master_repo_base}")
		file (MAKE_DIRECTORY "${master_repo_base}")
	endif ()
	sanity_make_flag(master_clone_flag "source.cache" "${library_name}" "master_clone")
	if (NOT EXISTS "${master_repo}")
		FILE (REMOVE "${master_clone_flag}")
	endif ()
	if (NOT EXISTS "${master_clone_flag}")
		if (EXISTS "${master_repo}")
			FILE (REMOVE_RECURSE "${master_repo}")
		endif ()
		MESSAGE(STATUS "cd ${master_repo_base} && git --mirror --progress clone ${origin} ${master_repo_name}" )
		execute_process(COMMAND "git" "clone" 
								"--mirror"
								"--progress"
								"${origin}" 
								"${master_repo_name}"
			    	WORKING_DIRECTORY ${master_repo_base}
			    	RESULT_VARIABLE res)
		if (res) 
			message (FATAL_ERROR "${res}")
		endif ()
		sanity_touch_flag(master_clone_flag)
	endif ()


	sanity_make_current_system_flag(create_repo PACKAGE "${package_name}" FUNCTION "create_repo")
	sanity_make_current_system_flag(checkout PACKAGE "${package_name}" FUNCTION "checkout")
	sanity_current_system_path(SRC local_src)
	set (src "${local_src}/${package_name}")

	if (NOT EXISTS ${src})
		FILE (REMOVE ${create_repo})
	endif ()
	if (NOT EXISTS ${create_repo})
		FILE (REMOVE_RECURSE ${src})
		execute_process(COMMAND "git" "clone" "--shared" "${master_repo}" "${package_name}"
			WORKING_DIRECTORY  "${local_src}" 
			RESULT_VARIABLE res)
		if (res) 
			message (FATAL_ERROR "${res}")
		endif ()
	endif ()

	execute_process(COMMAND "git" "rev-parse" "HEAD" 
			WORKING_DIRECTORY  "${src}" 
			OUTPUT_VARIABLE out OUTPUT_STRIP_TRAILING_WHITESPACE 
			RESULT_VARIABLE res)
	if (res) 
		message (FATAL_ERROR "${res}")
	endif ()
	if (NOT "${out}" STREQUAL "${required_commit}")
		FILE (REMOVE ${checkout})
	endif ()

	set ("${checkout_flag_name}" "${checkout}" PARENT_SCOPE)




endfunction()
