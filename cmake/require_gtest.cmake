include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

function (sanity_require_gtest version_arg)
    set (versions 1.7.0)
    set (hashes 4ff6353b2560df0afecfbda3b2763847)
    set (manual_installs ON)
    sanity_back(versions latest_version)

    sanity_deduce_version(${version_arg} versions gtest version version_index)
    if (NOT version)
            message (FATAL_ERROR "unable to deduce version")
    endif ()

#
# re-entry check
#
    if (sanity.require_gtest.complete)
            return ()
    endif ()

#
# find index of this version in version list
# and set up dependent variables
#
    list (GET hashes ${version_index} source_hash)
    list (GET manual_installs ${version_index} manual_install)

# download source

    set (version_string "release-${version}")
    set (package_name "googletest-${version_string}")
    set (source_url "https://codeload.github.com/google/googletest/tar.gz/${version_string}")
    set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
    set (source_tree "${sanity.source.cache.source}/${package_name}")
    set (build_dir ${sanity.target.build}/${package_name})

    if (NOT EXISTS ${source_url})
            sanity_download(URL ${source_url} PATH ${source_gz}
                    HASH_METHOD MD5
                    HASH_EXPECTED ${source_hash}
                    ERROR_RESULT result)
            if (result)
                    message (FATAL_ERROR "${result}")
            endif ()
    endif ()
	
# maybe untar
    sanity_make_flag(untar_flag "source.cache" "${package_name}" "untar")
    if ("${source_gz}" IS_NEWER_THAN "${untar_flag}" OR "${source_gz}" IS_NEWER_THAN "${build_dir}")
            message (STATUS "sanity_require_gtest - untar ${source_gz}")
            execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
                                    WORKING_DIRECTORY ${sanity.source.cache.source}
                                    RESULT_VARIABLE res)
            if (res)
                message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
            endif ()
            sanity_touch_flag(untar_flag)
    endif()

#
# maybe configure the build
#
    find_package(Threads)
    sanity_make_flag(run_cmake_flag "target" "${package_name}" "cmake")
    if ("${untar_flag}" IS_NEWER_THAN "${run_cmake_flag}")
            file(MAKE_DIRECTORY ${build_dir})
            set (args)
            set (prefix_paths ${CMAKE_PREFIX_PATH})
            list (APPEND prefix_paths "${sanity.target.local}")
            list (REMOVE_DUPLICATES prefix_paths)
            sanity_join(prefix_paths_string ";" ${prefix_paths})
            list(APPEND args 	   			
                    "-DCMAKE_PREFIX_PATH=${prefix_paths_string}"
                    "-DCMAKE_INSTALL_PREFIX=${sanity.target.local}"
                    "-DGTEST_USE_OWN_TR1_TUPLE=1")
            execute_process(
                    COMMAND ${CMAKE_COMMAND}
                    ${args}
                    ${source_tree}
                    WORKING_DIRECTORY ${build_dir}
                    RESULT_VARIABLE res)
            if (res)
                    message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
            endif ()
            sanity_touch_flag(run_cmake_flag)
    endif ()

#
# maybe build the library
#
    sanity_make_flag(run_make_flag "target" "${package_name}" "make")
    if ("${run_cmake_flag}" IS_NEWER_THAN "${run_make_flag}")
            execute_process(COMMAND make -j4 
                                            WORKING_DIRECTORY ${build_dir}
                                            RESULT_VARIABLE res)
            if (res)
                    message (FATAL_ERROR "failed to build gtest - ${res}") 
            endif ()
            sanity_touch_flag(run_make_flag)
    endif ()

    sanity_make_flag(install_flag "target" "${package_name}" "install")
    if ("${run_make_flag}" IS_NEWER_THAN "${install_flag}")
        if (manual_install)
            file(COPY "${build_dir}/libgtest.a" DESTINATION "${sanity.target.local}/lib")
            file(COPY "${build_dir}/libgtest_main.a" DESTINATION "${sanity.target.local}/lib")
            file(COPY "${source_tree}/include/gtest" DESTINATION "${sanity.target.local}/include")
        else ()
            execute_process(COMMAND make install 
                                    WORKING_DIRECTORY ${build_dir}
                                    RESULT_VARIABLE res)
            if (res)
                    message (FATAL_ERROR "failed to install gtest - ${res}") 
            endif ()
        endif ()
        sanity_touch_flag(install_flag)
    endif ()

#
# simulate outputs of FindGTest
#
    sanity_propagate_value (NAME GTEST_FOUND VALUE TRUE)
    sanity_propagate_value (NAME GTEST_INCLUDE_DIRS VALUE "${sanity.target.local}/include")
    sanity_propagate_value (NAME GTEST_LIBRARIES VALUE "${sanity.target.local}/lib/libgtest.a")
    sanity_propagate_value (NAME GTEST_MAIN_LIBRARIES VALUE "${sanity.target.local}/lib/libgtest_main.a")
    sanity_propagate_value (NAME GTEST_BOTH_LIBRARIES VALUE ${GTEST_MAIN_LIBRARIES} ${GTEST_LIBRARIES})
    sanity_propagate_value (NAME GTEST_LIBRARY_DIRS VALUE "${sanity.target.local}/lib")


#
# set unputs for future invocations of FindGTest
#
    sanity_propagate_value (NAME GTEST_ROOT VALUE "${sanity.target.local}")
    sanity_propagate_value (NAME GTEST_LIBRARY VALUE "${sanity.target.local}/lib/libgtest.a") 
    sanity_propagate_value (NAME GTEST_INCLUDE_DIR VALUE "${sanity.target.local}/include")
    sanity_propagate_value (NAME GTEST_MAIN_LIBRARY VALUE "${sanity.target.local}/lib/libgtest_main.a")


    find_package(Threads)


    if (NOT TARGET sanity::gtest)
            add_library(sanity::gtest INTERFACE IMPORTED GLOBAL)
            target_link_libraries(sanity::gtest INTERFACE 
                    ${GTEST_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} 
                    ${CMAKE_DL_LIBS})
            set_target_properties(sanity::gtest PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${GTEST_INCLUDE_DIRS})
    endif ()

    if (NOT TARGET sanity::gtest::main)
            add_library(sanity::gtest::main INTERFACE IMPORTED GLOBAL)
            target_link_libraries(sanity::gtest::main INTERFACE ${GTEST_MAIN_LIBRARIES} sanity::gtest)
    endif ()

    if (NOT TARGET gtest)
            add_library(gtest INTERFACE IMPORTED GLOBAL)
            target_link_libraries(gtest INTERFACE sanity::gtest)
    endif ()

    if (NOT TARGET gtest_main)
            add_library(gtest_main INTERFACE IMPORTED GLOBAL)
            target_link_libraries(gtest_main INTERFACE sanity::gtest::main)
    endif ()

    set (sanity.require_gtest.complete TRUE)
    sanity_propagate_vars(CMAKE_THREAD_LIBS_INIT 
                            CMAKE_USE_SPROC_INIT
                            CMAKE_USE_WIN32_THREADS_INIT
                            CMAKE_USE_PTHREADS_INIT
                            CMAKE_HP_PTHREADS_INIT
                            CMAKE_DL_LIBS
                            sanity.require_gtest.complete)

endfunction ()
