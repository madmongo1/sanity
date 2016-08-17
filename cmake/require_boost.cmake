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

function (boost_make_archive_pathname outvar)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})

    if (NOT outvar OR NOT ARG_VERSION)
        message (FATAL_ERROR "boost_make_archive_pathname(${ARGN})")
    endif ()

    boost_make_package_name(package_name VERSION "${ARG_VERSION}")
    set (archive_name "${sanity.source.cache.archive}/${package_name}.tar.bz2")
    set (${outvar} "${archive_name}" PARENT_SCOPE)
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
                                MD5
                                65a840e1a0b13a558ff19eeb2c4f0cbe)
    set (version_details_1.61.0 "https://sourceforge.net/projects/boost/files/boost/1.61.0/boost_1_61_0.tar.bz2/download"
                                MD5
                                6095876341956f65f9d35939ccea1a9f)

    set(version_details_tuple "version_details_${ARG_VERSION}")
    list (LENGTH "${version_details_tuple}" check)
    if (NOT check EQUAL 3)
        message (STATUS "invalid version: function (boost_acquire_archive ${ARGN})")
        message (FATAL_ERROR "${version_details_tuple}=${${version_details_tuple}}")
    endif ()

    list (GET "${version_details_tuple}" 0 url)
    boost_make_archive_pathname(archive_path VERSION ${ARG_VERSION})
    list (GET "${version_details_tuple}" 1 hash_method)
    list (GET "${version_details_tuple}" 2 expected_hash)

    set (need_download OFF)
    if (NOT EXISTS "${archive_path}")
        set (need_download ON)
    else ()
        file ("${hash_method}" "${archive_path}" current_hash)
        if (NOT current_hash STREQUAL expected_hash)
            set (need_download ON)
        endif ()
    endif ()

    if (need_download)
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

# \brief turn a version string into a boost source tree name
# \brief @param outvar is the name of the variable to populate
# \brief @param VERSION <version> is the version of boost
# \brief @returns outvar
function (boost_make_source_tree_pathname outvar)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})

    if (NOT outvar OR NOT ARG_VERSION)
        message (FATAL_ERROR "boost_make_source_tree_pathname(${ARGN})")
    endif ()

    boost_make_package_name(package_name VERSION "${ARG_VERSION}")
    sanity_current_system_path(SRC source_base)
    set (source_tree "${source_base}/${package_name}")
    set (${outvar} "${source_tree}" PARENT_SCOPE)

endfunction ()

function (boost_unpack_source outvar)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT outvar OR NOT ARG_VERSION)
        message (FATAL_ERROR "boost_unpack_source(${ARGV})")
    endif ()

    boost_make_package_name (package_name VERSION ${ARG_VERSION})
    boost_make_archive_pathname (archive_path VERSION ${ARG_VERSION})
    sanity_current_system_path(SRC source_base)
    boost_make_source_tree_pathname (source_tree VERSION ${ARG_VERSION})

    sanity_make_current_system_flag(untar_flag PACKAGE "${package_name}" FUNCTION "untar")

    if (${archive_path} IS_NEWER_THAN ${untar_flag}
            OR ${archive_path} IS_NEWER_THAN ${source_tree})
        message (STATUS "unpacking boost source from [${archive_path}] to [${source_tree}]")
        execute_process(COMMAND ${CMAKE_COMMAND} -E 
            tar xzf ${archive_path}
            WORKING_DIRECTORY ${source_base}
            RESULT_VARIABLE res)
        if (res)
                message(FATAL_ERROR "error in command tar xzf ${archive_path} : ${res}")
        endif ()
        sanity_touch_flag(untar_flag)
    endif()

    set (${outvar} "${source_tree}" PARENT_SCOPE)
    set (untar_flag "${untar_flag}" PARENT_SCOPE)
endfunction ()


# bootstrap needs to be done once per build system
# the actual options can be set on each invocation of b2
function (boost_bootstrap)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs COMPONENTS)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT ARG_VERSION)
        message (FATAL_ERROR "boost_bootstrap(${ARGV})")
    endif ()

    boost_make_package_name (package_name VERSION ${ARG_VERSION})
    boost_make_source_tree_pathname (source_tree VERSION ${ARG_VERSION})
    sanity_make_current_system_flag(untar_flag PACKAGE "${package_name}" FUNCTION "untar")
    sanity_make_current_system_flag(bootstrap_flag PACKAGE "${package_name}" FUNCTION "bootstrap")
    set (need_bootstrap)
    set (bootstrap_args)
    sanity_make_current_system_flag(bootstrap_needed PACKAGE "${package_name}" FUNCTION "bootstrap_needed")
    if ("${untar_flag}" IS_NEWER_THAN "${bootstrap_needed}" OR NOT EXISTS "${bootstrap_needed}")
        set (need_bootstrap TRUE)
        sanity_touch_flag(bootstrap_needed)
        message (STATUS "bootstrap needed because ${untar_flag} IS_NEWER_THAN ${bootstrap_needed}")
    endif ()
    set (bootstrapped_components ${sanity.boost.${sanity.current.system}.bootstrapped_components})
    list (APPEND bootstrapped_components ${ARG_COMPONENTS})
    if (bootstrapped_components)
        list (REMOVE_DUPLICATES bootstrapped_components)
    endif ()
    set ("sanity.boost.${sanity.current.system}.bootstrapped_components" 
            ${bootstrapped_components}
            CACHE INTERNAL "the complete set of boost components required by this project")

    set (really_need_bootstrap NO)
    foreach (component IN LISTS bootstrapped_components)
        sanity_make_current_system_flag(component_flag PACKAGE "${package_name}" FUNCTION "boost.bootstrap.${component}")
        if ("${bootstrap_needed}" IS_NEWER_THAN "${component_flag}" OR NOT EXISTS "${component_flag}")
            message (STATUS "bootstrap needed because ${bootstrap_needed} IS_NEWER_THAN ${component_flag}")
            set (need_bootstrap ON)
            set (really_need_bootstrap YES)
        endif ()
        if (component STREQUAL "regex")
            sanity_require (LIBRARY icu VERSION any)
            set (has_icu ON)
        endif ()
    endforeach ()

    if (need_bootstrap)
        if (really_need_bootstrap)
            sanity_join(liblist "," ${bootstrapped_components})
            sanity_current_system_path(LOCAL prefix_path)
            set (bootstrap_args "--prefix=${prefix_path}"
                                "--with-libraries=${liblist}")
            if (has_icu)
                list (APPEND bootstrap_args "--with-icu=${prefix_path}")
            else ()
                list (APPEND bootstrap_args "--without-icu")
            endif ()

            #target-specific code would go here

            message (STATUS "bootstrapping boost for ${sanity.current.system} with arguments: ${bootstrap_args}")
            execute_process(COMMAND ./bootstrap.sh 
                                    ${bootstrap_args}
                            WORKING_DIRECTORY ${source_tree}
                            RESULT_VARIABLE res)
            if (res)
                    message (FATAL_ERROR "bootstrap : ${res}")
            endif ()
        endif ()
        sanity_touch_flag(bootstrap_flag)
        foreach (component IN LISTS bootstrapped_components)
            sanity_make_current_system_flag(component_flag PACKAGE "${package_name}" FUNCTION "boost.bootstrap.${component}")
            sanity_touch_flag (component_flag)
        endforeach ()
    endif ()

endfunction ()

function (boost_build)
    set(options)
    set(oneValueArgs VERSION)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT ARG_VERSION)
        message (FATAL_ERROR "boost_build(${ARGV})")
    endif ()

    boost_make_package_name (package_name VERSION ${ARG_VERSION})
    boost_make_source_tree_pathname (source_tree VERSION ${ARG_VERSION})
    sanity_make_current_system_flag(bootstrap_flag PACKAGE "${package_name}" FUNCTION "bootstrap")
    sanity_make_current_system_flag(build_flag PACKAGE "${package_name}" FUNCTION "build")

    boost_make_source_tree_pathname (source_tree VERSION ${ARG_VERSION})
    sanity_current_system_path(BUILD build_prefix)
    set (build_dir "${build_prefix}/${package_name}")
    
    set (need_build)
    if ("${bootstrap_flag}" IS_NEWER_THAN "${build_flag}")
        message (STATUS "${bootstrap_flag} IS_NEWER_THAN ${build_flag}")
        set (need_build YES)
    endif ()
    if (NOT EXISTS "${build_dir}")
        message (STATUS "NOT EXISTS ${build_dir}")
        set (need_build YES)
    endif ()
    if (need_build)
        file(MAKE_DIRECTORY ${build_dir})

        set (bootstrapped_components ${sanity.boost.${sanity.current.system}.bootstrapped_components})
        list (LENGTH bootstrapped_components len)
        if (len EQUAL 0)
            #just need to copy headers
            sanity_current_system_path(LOCAL prefix_path)
            file (MAKE_DIRECTORY "${prefix_path}/include")
            file (COPY "${source_tree}/boost" DESTINATION "${prefix_path}/include")
        else ()
#target-specific stuff should go here
            set (b2_args)
            list (APPEND b2_args    "--build-dir=${build_dir}"
                                    "variant=release" 
                                    "link=static" 
                                    "threading=multi" 
                                    "runtime-link=shared" 
                                    "cxxflags='-std=c++11 -DBOOST_TYPEOF_NATIVE -DBOOST_SYSTEM_NO_DEPRECATED'"
                                    "-j${sanity.concurrency}")
#							"-sICU_PATH=${sanity.target.local}")
            if (APPLE)
            elseif (UNIX)
                    list (APPEND b2_args "linkflags=-lpthread -ldl")
            endif ()
            sanity_join(arg_string " " ${b2_args})
            message (STATUS "building boost for ${sanity.current.system} with args: ${arg_string}")
            execute_process(COMMAND ./b2 
                                ${b2_args}
                                install
                            WORKING_DIRECTORY ${source_tree}
                            RESULT_VARIABLE res)
            if (res)
                message (FATAL_ERROR "build failure: ${res}")
            endif ()
        endif ()
    endif ()
    sanity_touch_flag (build_flag)

endfunction ()

# compute the boost component dependency list for a given component
function (boost_dependency_list outvar)
    set(options)
    set(oneValueArgs VERSION COMPONENT)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT ARG_COMPONENT)
        message (FATAL_ERROR "boost_dependency_list(${ARGV})")
    endif ()

    set (boost.dependencies.log filesystem system date_time thread regex)
    set (boost.dependencies.thread system chrono date_time)

    set (list_name "boost.dependencies.${ARG_COMPONENT}")
    set (${outvar} ${${list_name}} PARENT_SCOPE)

endfunction ()

function (boost_append_real_libs inoutvar)
    set(options)
    set(oneValueArgs COMPONENT LIBDIR)
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT ARG_COMPONENT OR NOT ARG_LIBDIR OR NOT ARG_INCLUDES OR NOT inoutvar)
        message (FATAL_ERROR "boost_make_target(${ARGV})")
    endif ()
    if (NOT sanity.current.system STREQUAL "target")
        message (FATAL_ERROR "boost_make_target: assert - sanity.current.system STREQUAL target")
    endif ()

    set (result ${${inoutvar}})
    if ("${ARG_COMPONENT}" STREQUAL "log")
        list(APPEND result "${ARG_LIBDIR}/libboost_log_setup.a" "${ARG_LIBDIR}/libboost_log.a")
    else()
        list(APPEND result "${ARG_LIBDIR}/libboost_${ARG_COMPONENT}.a")
    endif ()

    boost_dependency_list(deps COMPONENT ${ARG_COMPONENT})
    foreach (dep IN LISTS deps)
#        message (STATUS "------ before ${dep}=${result}")
        boost_append_real_libs(result COMPONENT ${dep} LIBDIR ${ARG_LIBDIR})
#        message (STATUS "------ after ${dep}=${result}")
    endforeach ()

#    message (STATUS "------ result=${result}")
    set (${inoutvar} ${result} PARENT_SCOPE)

endfunction ()

function (boost_make_target)
    set(options)
    set(oneValueArgs COMPONENT LIBDIR)
    set(multiValueArgs INCLUDES)
    cmake_parse_arguments(ARG "${options}" 
                              "${oneValueArgs}" "${multiValueArgs}"
                              ${ARGN})
    if (NOT ARG_COMPONENT OR NOT ARG_LIBDIR OR NOT ARG_INCLUDES)
        message (FATAL_ERROR "boost_make_target(${ARGV})")
    endif ()
    if (NOT sanity.current.system STREQUAL "target")
        message (FATAL_ERROR "boost_make_target: assert - sanity.current.system STREQUAL target")
    endif ()

    string (TOUPPER ${ARG_COMPONENT} upper_component)
    sanity_propagate_value(NAME "Boost_${upper_component}_FOUND" VALUE "ON")
    if ("${component}" STREQUAL "log")
        sanity_propagate_value(NAME "Boost_${upper_component}_LIBRARY" 
                                VALUE "${ARG_LIBDIR}/libboost_log_setup.a"
                                VALUE "${ARG_LIBDIR}/libboost_log.a")
    else ()
        sanity_propagate_value(NAME "Boost_${upper_component}_LIBRARY" 
                                VALUE "${ARG_LIBDIR}/libboost_${ARG_COMPONENT}.a")
    endif ()

    if (NOT TARGET "boost_${ARG_COMPONENT}")
        message (STATUS "making target boost_${ARG_COMPONENT}")
        add_library("boost_${ARG_COMPONENT}" INTERFACE IMPORTED GLOBAL)
        target_link_libraries("boost_${ARG_COMPONENT}" 
                                INTERFACE "${Boost_${upper_component}_LIBRARY}")
        set_target_properties("boost_${ARG_COMPONENT}" 
                                PROPERTIES INTERFACE_INCLUDE_DIRECTORIES 
                                ${ARG_INCLUDES})
    endif ()

    set (real_libs)
    boost_append_real_libs(real_libs COMPONENT ${ARG_COMPONENT} LIBDIR ${ARG_LIBDIR})
    list(FIND reallibs "${ARG_LIBDIR}/libboost_thread.a" ithread)
    if (ithread)
        find_package(Threads)
        list (APPEND reallibs "${CMAKE_THREAD_LIBS_INIT}")
    endif ()

    if (NOT TARGET "sanity::boost::${ARG_COMPONENT}")
        message (STATUS "making target sanity::boost::${ARG_COMPONENT} IMPORTS ${real_libs}")

        add_library("sanity::boost::${ARG_COMPONENT}" INTERFACE IMPORTED GLOBAL)
        target_link_libraries("sanity::boost::${ARG_COMPONENT}" 
                                INTERFACE ${real_libs})
        set_target_properties("sanity::boost::${ARG_COMPONENT}" 
                                PROPERTIES INTERFACE_INCLUDE_DIRECTORIES 
                                ${ARG_INCLUDES})
    endif ()

    if (NOT TARGET "boost::${ARG_COMPONENT}")
        message (STATUS "making target boost::${ARG_COMPONENT} IMPORTS ${real_libs}")

        add_library("boost::${ARG_COMPONENT}" INTERFACE IMPORTED GLOBAL)
        target_link_libraries("boost::${ARG_COMPONENT}" 
                                INTERFACE ${real_libs})
        set_target_properties("boost::${ARG_COMPONENT}" 
                                PROPERTIES INTERFACE_INCLUDE_DIRECTORIES 
                                ${ARG_INCLUDES})
    endif ()

    sanity_propagate_vars ()

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
    boost_unpack_source(source_tree VERSION ${version})
#    if (sanity.current.system STREQUAL "target")
#        sanity_require (LIBRARY openssl VERSION any)
#        sanity_require (LIBRARY icu VERSION any)
#    endif ()
    set(all_components)
    foreach (component IN LISTS ARG_COMPONENTS)
        boost_dependency_list(dependencies COMPONENT ${component})
        list (APPEND all_components ${component} ${dependencies})
        list (REMOVE_DUPLICATES all_components)
    endforeach ()

    message (STATUS "all components are: ${all_components}")

    boost_bootstrap(VERSION ${version} COMPONENTS ${all_components})
    boost_build(VERSION ${version})

    #
    # prerequisites
    #
#	sanity_require (LIBRARY openssl VERSION any)
#	sanity_require (LIBRARY icu VERSION any)

#
# make the targets
#
    if (NOT "${sanity.current.system}" STREQUAL "target")
        sanity_propagate_vars ()
        return ()
    endif ()
    find_package(Threads)
    set (Boost_FOUND TRUE)
    set (Boost_INCLUDE_DIRS ${sanity.target.local}/include)
    set (Boost_LIBRARY_DIRS ${sanity.target.local}/lib)
    
    if (NOT TARGET boost)
        add_library(boost INTERFACE IMPORTED GLOBAL)
#            target_link_libraries(boost INTERFACE 
#                    ${CMAKE_THREAD_LIBS_INIT} 
#                    ${CMAKE_DL_LIBS})
        set_target_properties(boost PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${Boost_INCLUDE_DIRS})
        set_target_properties(boost PROPERTIES 
            INTERFACE_COMPILE_DEFINITIONS 
            "BOOST_TYPEOF_NATIVE;BOOST_SYSTEM_NO_DEPRECATED")
    endif ()

    if (NOT TARGET sanity::boost)
            add_library (sanity::boost IMPORTED INTERFACE GLOBAL)
            target_link_libraries (sanity::boost INTERFACE boost)
    endif ()

    set (BOOST_ROOT ${sanity.target.local})
    set (BOOST_INCLUDEDIR ${sanity.target.local}/include)
    set (BOOST_LIBRARYDIR ${sanity.target.local}/lib)
    set (Boost_NO_SYSTEM_PATHS ON)
    set (Boost_USE_STATIC_LIBS ON)

    foreach (component IN LISTS sanity.boost.${sanity.current.system}.bootstrapped_components)
        boost_make_target (COMPONENT "${component}"
                            LIBDIR "${BOOST_LIBRARYDIR}"
                            INCLUDES "${BOOST_INCLUDEDIR}")
    endforeach ()


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
