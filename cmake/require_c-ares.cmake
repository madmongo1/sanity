include(${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/sanity_get_repo.cmake)

function(sanity_require_c_ares given_version)

    # invariants
    set(library c-ares)
    set(originRepoURL "git@github.com:c-ares/c-ares.git")
    set(versions 1.12.1)
    set(commits)
    list(APPEND commits "d6823a5cf398a0df48792f4f90d68b9febe7d92f")

    #derived data
    sanity_back(versions latest_version)

    sanity_deduce_version(${given_version} versions ${library} version version_index)
    if (NOT version)
        message(FATAL_ERROR "unable to deduce version")
    endif ()

    set(complete_flag "sanity.require_${library}.complete")
    if (${${complete_flag}})
        return()
    endif ()

    sanity_current_system_path(LOCAL localBase FLAGS flagsBase BUILD buildBase SRC srcBase)
    set(package_name "${library}-${version}")
    set(build_dir ${buildBase}/${package_name})
    set(packageDir "${localBase}")

    list(GET commits ${version_index} requiredCommit)


    sanity_ensure_master_repo(REPO_NAME ${library} URL ${originRepoURL} OUTVAR masterRepoDir)
    sanity_ensure_subordinate_repo(MASTER_REPO_DIR ${masterRepoDir} PACKAGE_NAME ${package_name} COMMIT ${requiredCommit} OUTVAR sourceTree)

    sanity_make_current_system_flag(configureFlag PACKAGE "${package_name}" FUNCTION "configure")
    if (NOT EXISTS "${configureFlag}"
            OR "${CMAKE_CURRENT_LIST_FILE}" IS_NEWER_THAN "${configureFlag}")
        message(STATUS "########")
        message(STATUS "configuring ${package_name}")
        message(STATUS "########")
        file(MAKE_DIRECTORY ${build_dir})
        set(args)
        list(APPEND args
                "-DCMAKE_INSTALL_PREFIX=${packageDir}"
                "-DCMAKE_PREFIX_PATH=${localBase}"
                "-DCARES_STATIC=BOOL:ON")
        if (CMAKE_TOOLCHAIN_FILE)
            list(APPEND args "-T${CMAKE_TOOLCHAIN_FILE}")
        endif ()
        set(cmdList ${CMAKE_COMMAND} ${args} ${sourceTree})
        sanity_join(command " " ${cmdList})
        message(STATUS "$ ${command}")
        execute_process(
                COMMAND ${cmdList}
                WORKING_DIRECTORY ${build_dir}
                RESULT_VARIABLE res)

        if (res)
            message(FATAL_ERROR "configure command failed with code ${res}")
        endif ()
        sanity_touch_flag(configureFlag)
    endif ()

    sanity_make_current_system_flag(buildFlag PACKAGE "${package_name}" FUNCTION "build")
    if ("${configureFlag}" IS_NEWER_THAN "${buildFlag}")
        message(STATUS "########")
        message(STATUS "building ${package_name}")
        message(STATUS "########")
        execute_process(COMMAND ${CMAKE_MAKE_PROGRAM} "-j${sanity.concurrency}"
                WORKING_DIRECTORY "${build_dir}"
                RESULT_VARIABLE res)
        if (res)
            message(FATAL_ERROR "build failed: ${res}")
        endif ()
        execute_process(COMMAND ${CMAKE_MAKE_PROGRAM} "install"
                WORKING_DIRECTORY "${build_dir}"
                RESULT_VARIABLE res)
        if (res)
            message(FATAL_ERROR "install failed: ${res}")
        endif ()
        sanity_touch_flag(buildFlag)
    endif ()

    find_package(Threads)
    set(CARES_ROOT "${packageDir}")
    set(CARES_INCLUDE_DIR "${CARES_ROOT}/include")
    set(CARES_LIBRARIES "${CARES_ROOT}/lib/libcares.a")
    set(CARES_FOUND YES)
    set(component_names CARES_ROOT CARES_INCLUDE_DIR CARES_LIBRARIES CARES_FOUND)

    if (NOT TARGET sanity_cares)
        add_library(sanity_cares INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity_cares
                INTERFACE ${CARES_LIBRARIES})
        set_property(TARGET sanity_cares
                APPEND
                PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${CARES_INCLUDE_DIRS})
    endif ()

    if (NOT TARGET sanity::cares)
        add_library(sanity::cares INTERFACE IMPORTED GLOBAL)
        target_link_libraries(sanity::cares
                INTERFACE ${CARES_LIBRARIES})
        set_property(TARGET sanity_cares
                APPEND
                PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${CARES_INCLUDE_DIRS})
    endif ()

    set(${complete_flag} YES PARENT_SCOPE)

    sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT
            CMAKE_USE_SPROC_INIT
            CMAKE_USE_WIN32_THREADS_INIT
            CMAKE_USE_PTHREADS_INIT
            CMAKE_HP_PTHREADS_INIT
            CMAKE_DL_LIBS
            ${component_names}
            ${complete_flag})

endfunction()
