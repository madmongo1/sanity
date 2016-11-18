if (sanity.function.sanity_get_repo.included)
    return()
endif ()
set(sanity.function.sanity_get_repo.included TRUE)

# Check whether a git repo has a given commit
# @param REPO_DIR is the path to the local repository
# @param COMMIT number or tag to find
# @param OUTVAR variable to put the result in. The result will be YES or NO
# @returns YES/NO
function(sanity_check_repo_has_commit)
    set(options)
    set(oneValueArgs REPO_DIR COMMIT OUTVAR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})

    set(RESULT NO)

    if (NOT ARG_REPO_DIR)
        message(FATAL_ERROR "REPO_DIR not set")
    endif ()

    if (NOT ARG_COMMIT)
        message(FATAL_ERROR "COMMIT not set")
    endif ()

    if (NOT ARG_OUTVAR)
        message(FATAL_ERROR "OUTVAR not set")
    endif ()

    execute_process(COMMAND "git" "branch" "--contains" "${ARG_COMMIT}"
            WORKING_DIRECTORY "${ARG_REPO_DIR}"
            RESULT_VARIABLE res)
    if (res)
        message(STATUS "checking for commit ${ARG_COMMIT} in repo ${ARG_REPO_DIR} yields NO")
        set(RESULT NO)
    else ()
        set(RESULT YES)
    endif ()

    set("${ARG_OUTVAR}" "${RESULT}" PARENT_SCOPE)

endfunction(sanity_check_repo_has_commit)

# Perform a fetch on a git repo
# @param REPO_DIR is the path to the local repository
function(sanity_git_fetch)
    set(options)
    set(oneValueArgs REPO_DIR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})

    if (NOT ARG_REPO_DIR)
        message(FATAL_ERROR "REPO_DIR not set")
    endif ()

    execute_process(COMMAND "git" "fetch"
            WORKING_DIRECTORY "${ARG_REPO_DIR}"
            RESULT_VARIABLE res
            ERROR_VARIABLE errorText)
    if (res)
        message(FATAL_ERROR "performing git fetch in repo ${ARG_REPO_DIR} failed with error ${res}:\n ${errorText}")
    endif ()

endfunction(sanity_git_fetch)

# set the given repo to the given commit. Fail if not possible
function(sanity_set_git_commit)
    set(options)
    set(oneValueArgs REPO_DIR COMMIT)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})

    if (NOT ARG_REPO_DIR)
        message(FATAL_ERROR "REPO_DIR not set")
    endif ()
    if (NOT ARG_COMMIT)
        message(FATAL_ERROR "COMMIT not set")
    endif ()

    sanit_check_repo_has_commit(REPO_DIR "${ARG_REPO_DIR}" COMMIT "${ARG_COMMIT}" OUTVAR "hasCommit")
    if (NOT "${hasCommit}")
        sanity_git_fetch(REPO_DIR "${ARG_REPO_DIR")
        sanit_check_repo_has_commit(REPO_DIR "${ARG_REPO_DIR}" COMMIT "${ARG_COMMIT}" OUTVAR "hasCommit")
        if (NOT "${hasCommit}")
            message(FATAL_ERROR "Cannot find commit ${ARG_COMMIT} in repo ${ARG_REPO_DIR}")
        endif ()
    endif ()

endfunction(sanity_set_git_commit)

function(sanity_git_repo_exists)
    set(options)
    set(oneValueArgs REPO_DIR OUTVAR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})
    if (NOT ARG_REPO_DIR)
        message(FATAL_ERROR "REPO_DIR is not set")
    endif ()
    if (NOT ARG_OUTVAR)
        message(FATAL_ERROR "OUTVAR is not set")
    endif ()

    set(result NO)
    if (EXISTS "${ARG_REPO_DIR}")
        set(result YES)
    endif ()

    set("${ARG_OUTVAR}" "${result}" PARENT_SCOPE)

endfunction(sanity_git_repo_exists)

# @param REPO_NAME is the name of the repository (e.g. curl, boost, etc)
# @param URL is the upstream url
# @param OUTVAR shall be populated with the path to the master repo
function(sanity_ensure_master_repo)
    set(options)
    set(oneValueArgs REPO_NAME URL OUTVAR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})
    if (NOT ARG_REPO_NAME)
        message(FATAL_ERROR "REPO_NAME is not set")
    endif ()
    if (NOT ARG_URL)
        message(FATAL_ERROR "URL is not set")
    endif ()
    if (NOT ARG_OUTVAR)
        message(FATAL_ERROR "OUTVAR is not set")
    endif ()

    set(masterRepoDir)
    set(result "")

    set(masterRepoBase "${sanity.source.cache}/git")
    if (NOT EXISTS "${masterRepoBase}")
        file(MAKE_DIRECTORY "${masterRepoBase}")
    endif ()
    set(masterRepoDir "${masterRepoBase}/${ARG_REPO_NAME}")
    sanity_git_repo_exists(REPO_DIR "${masterRepoDir}" OUTVAR masterExists)

    if (NOT masterExists)
        execute_process(COMMAND "git" "clone"
                "--mirror"
                "--progress"
                "${ARG_URL}"
                "${ARG_REPO_NAME}"
                WORKING_DIRECTORY ${masterRepoBase}
                RESULT_VARIABLE res
                ERROR_VARIABLE errText)
        if (res)
            message(FATAL_ERROR "git pull failed with code ${res}:\n${errText}")
        endif ()
    endif ()

    set("${ARG_OUTVAR}" "${masterRepoDir}" PARENT_SCOPE)
endfunction(sanity_ensure_master_repo)

function(sanity_ensure_subordinate_repo)
    set(options)
    set(oneValueArgs MASTER_REPO_DIR PACKAGE_NAME COMMIT OUTVAR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})

    if (NOT ARG_MASTER_REPO_DIR)
        message(FATAL_ERROR "MASTER_REPO_DIR is not set")
    endif ()
    if (NOT ARG_PACKAGE_NAME)
        message(FATAL_ERROR "PACKAGE_NAME is not set")
    endif ()

    if (NOT ARG_COMMIT)
        message(FATAL_ERROR "COMMIT is not set")
    endif ()

    if (NOT ARG_OUTVAR)
        message(FATAL_ERROR "OUTVAR is not set")
    endif ()

    sanity_git_repo_exists(REPO_DIR "${ARG_MASTER_REPO_DIR}" OUTVAR masterExists)
    if (NOT masterExists)
        message(FATAL_ERROR "master repo ${ARG_MASTER_REPO_DIR} does not exist")
    endif ()

    set(sourceBase "${sanity.cache.source}")
    set(subordinateRepoDir "${sourceBase}/${ARG_PACKAGE_NAME}")
    sanity_git_repo_exists(REPO_DIR "${subordinateRepoDir}" OUTVAR subordinateExists)
    if (NOT subordinateExists)
        execute_process(COMMAND "git" "clone" "--shared" "${ARG_MASTER_REPO_DIR}" "${ARG_PACKAGE_NAME}"
                WORKING_DIRECTORY "${sourceBase}"
                RESULT_VARIABLE res
                ERROR_VARIABLE errText)
        if (res)
            message(FATAL_ERROR "subordinate clone failed with code: ${res}\n${errText}")
        endif ()
    endif ()

    sanity_check_repo_has_commit(REPO_DIR "${subordinateRepoDir}" COMMIT "${ARG_COMMIT}" OUTVAR hasCommit)
    if (NOT hasCommit)
        execute_process(COMMAND "git" "fetch"
                WORKING_DIRECTORY "${subordinateRepoDir}"
                RESULT_VARIABLE res)
        if (res)
            message(FATAL_ERROR "failed to git fetch repo: ${subordinateRepoDir}")
        endif ()
        sanity_check_repo_has_commit(REPO_DIR "${subordinateRepoDir}" COMMIT "${ARG_COMMIT}" OUTVAR hasCommit)
        if (NOT hasCommit)
            message(FATAL_ERROR "cannot locate commit: ${ARG_COMMIT} in repo ${subordinateRepoDir}")
        endif ()
    endif ()

    execute_process(COMMAND "git" "rev-parse" "--symbolic" "${ARG_COMMIT}"
            WORKING_DIRECTORY "${subordinateRepoDir}"
            OUTPUT_VARIABLE out OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE res
            ERROR_VARIABLE errText)
    if (res)
        message(FATAL_ERROR "failed to get current branch ${res}\n${errorText}")
    endif ()
    if (NOT "${out}" STREQUAL "${ARG_COMMIT}")
        execute_process(COMMAND "git" "checkout" "--force" "${ARG_COMMIT}"
                WORKING_DIRECTORY "${subordinateRepoDir}"
                RESULT_VARIABLE res
                ERROR_VARIABLE errText)
        if (res)
            message(FATAL_ERROR "failed to checkout ${ARG_COMMIT} in repo ${subordinateRepoDir}\n${errText}")
        endif ()
    endif ()

    #@todo: submodule updates

    set("${ARG_OUTVAR}" "${subordinateRepoDir}" PARENT_SCOPE)

endfunction(sanity_ensure_subordinate_repo)

function(sanity_get_repo)

    set(options)
    set(oneValueArgs ORIGIN LIBRARY_NAME LIBRARY_VERSION REQUIRED_COMMIT CHECKOUT_FLAG)
    set(multiValueArgs)
    cmake_parse_arguments(SANITY_GET_REPO " ${options}"
            "${oneValueArgs}" "${multiValueArgs}"
            ${ARGN})

    set(master_repo_base "${sanity.source.cache}/git")

    if (NOT SANITY_GET_REPO_ORIGIN)
        message(FATAL_ERROR "ORIGIN not set")
    else ()
        set(origin "${SANITY_GET_REPO_ORIGIN}")
    endif ()

    if (NOT SANITY_GET_REPO_LIBRARY_NAME)
        message(FATAL_ERROR "LIBRARY_NAME not set")
    else ()
        set(library_name "${SANITY_GET_REPO_LIBRARY_NAME}")
        set(master_repo_name "${library_name}.git")
        set(master_repo "${master_repo_base}/${master_repo_name}")
    endif ()

    if (NOT SANITY_GET_REPO_LIBRARY_VERSION)
        message(FATAL_ERROR "LIBRARY_VERSION not set")
    else ()
        set(library_version "${SANITY_GET_REPO_LIBRARY_VERSION}")
        set(package_name "${library_name}-${library_version}")
    endif ()

    if (NOT SANITY_GET_REPO_REQUIRED_COMMIT)
        message(FATAL_ERROR "REQUIRED_COMMIT not set")
    else ()
        set(required_commit "${SANITY_GET_REPO_REQUIRED_COMMIT}")
    endif ()

    if (NOT SANITY_GET_REPO_CHECKOUT_FLAG)
        message(FATAL_ERROR "CHECKOUT_FLAG not set")
    else ()
        set(checkout_flag_name "${SANITY_GET_REPO_CHECKOUT_FLAG}")
    endif ()


    if (NOT EXISTS "${master_repo_base}")
        file(MAKE_DIRECTORY "${master_repo_base}")
    endif ()
    sanity_make_flag(master_clone_flag "source.cache" "${library_name}" "master_clone")
    if (NOT EXISTS "${master_repo}")
        FILE(REMOVE "${master_clone_flag}")
    endif ()
    if (NOT EXISTS "${master_clone_flag}")
        if (EXISTS "${master_repo}")
            FILE(REMOVE_RECURSE "${master_repo}")
        endif ()
        MESSAGE(STATUS "cd ${master_repo_base} && git --mirror --progress clone ${origin} ${master_repo_name}")
        execute_process(COMMAND "git" "clone"
                "--mirror"
                "--progress"
                "${origin}"
                "${master_repo_name}"
                WORKING_DIRECTORY ${master_repo_base}
                RESULT_VARIABLE res)
        if (res)
            message(FATAL_ERROR "${res}")
        endif ()
        sanity_touch_flag(master_clone_flag)
    endif ()


    sanity_make_current_system_flag(create_repo PACKAGE "${package_name}" FUNCTION "create_repo")
    sanity_make_current_system_flag(checkout PACKAGE "${package_name}" FUNCTION "checkout")
    sanity_current_system_path(SRC local_src)
    set(src "${local_src}/${package_name}")

    if (NOT EXISTS ${src})
        FILE(REMOVE ${create_repo})
    endif ()
    if (NOT EXISTS ${create_repo})
        FILE(REMOVE_RECURSE ${src})
        execute_process(COMMAND "git" "clone" "--shared" "${master_repo}" "${package_name}"
                WORKING_DIRECTORY "${local_src}"
                RESULT_VARIABLE res)
        if (res)
            message(FATAL_ERROR "${res}")
        endif ()
    endif ()

    execute_process(COMMAND "git" "rev-parse" "HEAD"
            WORKING_DIRECTORY "${src}"
            OUTPUT_VARIABLE out OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE res)
    if (res)
        message(FATAL_ERROR "${res}")
    endif ()
    if (NOT "${out}" STREQUAL "${required_commit}")
        FILE(REMOVE ${checkout})
    endif ()

    set("${checkout_flag_name}" "${checkout} " PARENT_SCOPE)


endfunction()
