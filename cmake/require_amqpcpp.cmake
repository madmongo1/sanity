include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)


function (sanity_require_amqpcpp given_version)

	set (library amqpcpp)
	set (versions 2.6.1)
	set (hashes 383914c0c7468c720c51e06bd5f0655fa7d0f3bf)
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions ${library} version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	list (GET hashes ${version_index} required_commit)

	set (complete_flag "sanity.require_${library}.complete")
	if (${${complete_flag}})
		return ()
	endif ()

	set (repo_name AMQP-CPP)
	set (package_name "${library}-${version}")
	set (flag_base ${sanity.source.cache.flags}/)

	set (master_repo_base "${sanity.source.cache}/git")
	set (master_repo "${master_repo_base}/${repo_name}.git")
	
	if (NOT EXISTS "${master_repo_base}")
		file (MAKE_DIRECTORY "${master_repo_base}")
	endif ()
	sanity_make_flag(master_clone_flag "source.cache" "${package_name}" "master_clone")
	if (NOT EXISTS "${master_repo}")
		FILE (REMOVE "${master_clone_flag}")
	endif ()
	if (NOT EXISTS "${master_clone_flag}")
		if (EXISTS "${master_repo}")
			FILE (REMOVE_RECURSE "${master_repo}")
		endif ()
		execute_process(COMMAND "git" "clone" "https://github.com/madmongo1/${repo_name}.git"
								"--mirror"
								"--progress"
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

	if ("${create_repo}" IS_NEWER_THAN "${checkout}")
		execute_process(COMMAND "git" "checkout" "${required_commit}"
			WORKING_DIRECTORY  "${src}" RESULT_VARIABLE res)
		if (res) 
			message (FATAL_ERROR "${res}")
		endif ()
		sanity_touch_flag(checkout)
	endif ()

	sanity_make_current_system_flag(configure PACKAGE "${package_name}" FUNCTION "configure")
	sanity_current_system_path(BUILD local_build)
	sanity_current_system_path(LOCAL target_local)
	set (build_dir "${local_build}/${package_name}")

	if (NOT EXISTS "${build_dir}")
		FILE(REMOVE "${configure}")
		FILE(MAKE_DIRECTORY "${build_dir}")
	endif ()

	if ("${checkout}" IS_NEWER_THAN "${configure}")
		execute_process(COMMAND "${CMAKE_COMMAND}" 
			"-DCMAKE_PREFIX_PATH=${target_local}"
			"-DCMAKE_INSTALL_PREFIX:PATH=${target_local}"
			"${src}" 
			WORKING_DIRECTORY  "${build_dir}" 
			RESULT_VARIABLE res)
		if (res) 
			message (FATAL_ERROR "${res}")
		endif ()
		sanity_touch_flag(configure)
	endif ()

	sanity_make_current_system_flag(clean PACKAGE "${package_name}" FUNCTION "clean")
	sanity_make_current_system_flag(build PACKAGE "${package_name}" FUNCTION "build")
	sanity_make_current_system_flag(install PACKAGE "${package_name}" FUNCTION "install")

	if ("${configure}" IS_NEWER_THAN "${clean}")
		execute_process(COMMAND make "-j${sanity.concurrency}" clean
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(clean)
	endif ()

	if ("${clean}" IS_NEWER_THAN "${build}")
		execute_process(COMMAND make "-j${sanity.concurrency}"
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(build)
	endif ()

	if ("${build}" IS_NEWER_THAN "${install}")
		execute_process(COMMAND make install
						WORKING_DIRECTORY ${build_dir})
		sanity_touch_flag(install)
	endif ()


	set(component_names AMQPCPP_INCLUDE_DIRS AMQPCPP_LIBRARIES AMQPCPP_FOUND AMQPCPP_VERSION_STRING)
	set(AMQPCPP_INCLUDE_DIRS "${target_local}/include")
	set(AMQPCPP_LIBRARIES "${target_local}/lib/libamqp-cpp.a")
	set(AMQPCPP_FOUND True)
	set(AMQPCPP_VERSION_STRING "${version}")

	if (NOT TARGET sanity::amqpcpp)
		add_library(sanity::amqpcpp INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::amqpcpp 
                                INTERFACE ${AMQPCPP_LIBRARIES})
		set_property(TARGET sanity::amqpcpp
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${AMQPCPP_INCLUDE_DIRS})
	endif ()

	set (${complete_flag} TRUE)

	sanity_propagate_vars(${component_names}
						  ${complete_flag})


endfunction()