macro (copy_back)

    get_directory_property(hasParent PARENT_DIRECTORY)
    if(hasParent)
        set (SRCS ${SRCS} PARENT_SCOPE)
        set (BINARY_SRCS ${BINARY_SRCS} PARENT_SCOPE)
        set (NOCOMPILE_SOURCES ${NOCOMPILE_SOURCES} PARENT_SCOPE)
        set (NOCOMPILE_BINARIES ${NOCOMPILE_BINARIES} PARENT_SCOPE)
    endif()
endmacro()

macro (add_sources)
    foreach (_src ${ARGN})
        list (APPEND SRCS "${CMAKE_CURRENT_SOURCE_DIR}/${_src}")
    endforeach()
    copy_back()
endmacro()

macro (add_binaries)
    foreach (_src ${ARGN})
        list (APPEND BINARY_SRCS "${CMAKE_CURRENT_BINARY_DIR}/${_src}")
    endforeach()
    copy_back()
endmacro()

macro (add_configured_source infile outfile)
    configure_file(${infile} ${outfile})
    add_binaries(${outfile})
    list (APPEND NOCOMPILE_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/${infile}")
    copy_back()
endmacro()

macro (add_configured_resource infile outfile)
    configure_file(${infile} ${outfile})
    list (APPEND NOCOMPILE_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/${infile}")
    list (APPEND NOCOMPILE_BINARIES "${CMAKE_CURRENT_BINARY_DIR}/${outfile}")
    copy_back()
endmacro()


MACRO(SOURCE_GROUP_BY_FOLDER)
    FOREACH(file ${ARGN})
        file(RELATIVE_PATH relative_file "${CMAKE_CURRENT_SOURCE_DIR}" ${file})
        GET_FILENAME_COMPONENT(dir "${relative_file}" PATH)
        IF(dir)
            STRING(REPLACE "/" "\\\\" group_name ${dir})
            SOURCE_GROUP(${group_name} FILES ${file})
        ENDIF()
    ENDFOREACH(file)
ENDMACRO(SOURCE_GROUP_BY_FOLDER)

MACRO(BINARY_GROUP_BY_FOLDER)
    FOREACH(file ${ARGN})
        file(RELATIVE_PATH relative_file "${CMAKE_CURRENT_BINARY_DIR}" ${file})
        GET_FILENAME_COMPONENT(dir "${relative_file}" PATH)
        IF(dir)
            STRING(REPLACE "/" "\\\\" group_name ${dir})
            SOURCE_GROUP("Generated\\\\${group_name}" FILES ${file})
        ENDIF()
    ENDFOREACH(file)
ENDMACRO(BINARY_GROUP_BY_FOLDER)

MACRO(interface_tree subdir)
    set(SRCS)
    set(BINARY_SRCS)
    set(NOCOMPILE_SOURCES)
    set(NOCOMPILE_BINARIES)
    add_subdirectory(${subdir})
    list(APPEND INTERFACE_FILES ${SRCS} ${BINARY_SRCS})
    list(APPEND SOURCE_FILES ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES})
    source_group_by_folder(${SRCS} ${NOCOMPILE_SOURCES})
    binary_group_by_folder(${BINARY_SRCS})
    set_source_files_properties(${SRCS} ${BINARY_SRCS} ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES} PROPERTIES HEADER_FILE_ONLY TRUE)
    list(APPEND 
        DOCUMENTATION_INCLUDE_PATHS 
        "${CMAKE_CURRENT_SOURCE_DIR}/${subdir}" 
        "${CMAKE_CURRENT_BINARY_DIR}/${subdir}"
        )

    list(APPEND
        DOCUMENTATION_SOURCE_FILES
        ${SRCS} ${BINARY_SRCS}
        )

    list(APPEND DOCUMENTATION_STRIP_FROM_PATHS
        "${CMAKE_CURRENT_SOURCE_DIR}/${subdir}" 
        "${CMAKE_CURRENT_BINARY_DIR}/${subdir}"
    )

    get_directory_property(hasParent PARENT_DIRECTORY)
    if(hasParent)
        set(DOCUMENTATION_INCLUDE_PATHS ${DOCUMENTATION_INCLUDE_PATHS} PARENT_SCOPE)
        set(DOCUMENTATION_SOURCE_FILES ${DOCUMENTATION_SOURCE_FILES} PARENT_SCOPE)
        set(DOCUMENTATION_STRIP_FROM_PATHS ${DOCUMENTATION_STRIP_FROM_PATHS} PARENT_SCOPE)
    endif()

    
ENDMACRO()

MACRO(source_tree subdir)
    set(SRCS)
    set(BINARY_SRCS)
    set(NOCOMPILE_SOURCES)
    set(NOCOMPILE_BINARIES)
    add_subdirectory(${subdir})
    list(APPEND SOURCE_FILES ${SRCS} ${BINARY_SRCS})
    list(APPEND SOURCE_FILES ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES})
    source_group_by_folder(${SRCS} ${NOCOMPILE_SOURCES})
    binary_group_by_folder(${BINARY_SRCS} ${NOCOMPILE_BINARIES})
    set_source_files_properties(${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES} PROPERTIES HEADER_FILE_ONLY TRUE)
    list(APPEND 
        DOCUMENTATION_INCLUDE_PATHS 
        "${CMAKE_CURRENT_SOURCE_DIR}/${subdir}" 
        "${CMAKE_CURRENT_BINARY_DIR}/${subdir}"
        )

    list(APPEND
        DOCUMENTATION_SOURCE_FILES
        ${SRCS} ${BINARY_SRCS}
        )

    list(APPEND DOCUMENTATION_STRIP_FROM_PATHS
        "${CMAKE_CURRENT_SOURCE_DIR}/${subdir}" 
        "${CMAKE_CURRENT_BINARY_DIR}/${subdir}"
    )

    get_directory_property(hasParent PARENT_DIRECTORY)
    if(hasParent)
        set(DOCUMENTATION_INCLUDE_PATHS ${DOCUMENTATION_INCLUDE_PATHS} PARENT_SCOPE)
        set(DOCUMENTATION_SOURCE_FILES ${DOCUMENTATION_SOURCE_FILES} PARENT_SCOPE)
        set(DOCUMENTATION_STRIP_FROM_PATHS ${DOCUMENTATION_STRIP_FROM_PATHS} PARENT_SCOPE)
    endif()


ENDMACRO()

MACRO(test_tree subdir)
    set(SRCS)
    set(BINARY_SRCS)
    set(NOCOMPILE_SOURCES)
    set(NOCOMPILE_BINARIES)
    add_subdirectory(${subdir})
    list(APPEND TEST_FILES ${SRCS} ${BINARY_SRCS})
    list(APPEND TEST_FILES ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES})
    source_group_by_folder(${SRCS} ${NOCOMPILE_SOURCES})
    binary_group_by_folder(${BINARY_SRCS} ${NOCOMPILE_BINARIES})
    set_source_files_properties(${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES} PROPERTIES HEADER_FILE_ONLY TRUE)
ENDMACRO()

macro (add_web_resources)
    foreach(_resource ${ARGN})
        FILE(RELATIVE_PATH SERVERX_RESOURCE_NAME ${ASSET_ROOT} "${CMAKE_CURRENT_SOURCE_DIR}/${_resource}")

        SET(SERVERX_RESOURCE_NAME "/${SERVERX_RESOURCE_NAME}")
        SET(_filename "register-resource-${_resource}.cpp")
        set(_target_file "${CMAKE_CURRENT_BINARY_DIR}/${_filename}")
        SET(_rebuild FALSE)
        IF(EXISTS "${_target_file}")
            FILE(TIMESTAMP "${CMAKE_CURRENT_SOURCE_DIR}/${_resource}" RESOURCE_TIME)
            FILE(TIMESTAMP ${TEMPLATE_FILE} TEMPLATE_TIME)
            FILE(TIMESTAMP "${_target_file}" TARGET_TIME)

            IF((RESOURCE_TIME > TARGET_TIME) OR (TEMPLATE_TIME > TARGET_TIME) OR (NOT TARGET_TIME) )
                SET(_rebuild TRUE)
            ENDIF()
        ELSE()
            SET (_rebuild TRUE)
        ENDIF()
    
        IF (_rebuild)
            FILE(READ ${_resource} SERVERX_RESOURCE_CONTENT HEX)
            string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," SERVERX_RESOURCE_CONTENT ${SERVERX_RESOURCE_CONTENT})
            configure_file("${TEMPLATE_FILE}"
                "${_target_file}"
                @ONLY ESCAPE_QUOTES)
        ELSE()
        ENDIF()
        list(APPEND NOCOMPILE_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/${_resource}")
        list(APPEND BINARY_SRCS "${CMAKE_CURRENT_BINARY_DIR}/${_filename}")
    endforeach()
    copy_back()
endmacro()

MACRO(web_resource_tree subdir template_file)
    set(SRCS)
    set(BINARY_SRCS)
    set(NOCOMPILE_SOURCES)
    set(NOCOMPILE_BINARIES)
    set(ASSET_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/${subdir}")
    set(TEMPLATE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${template_file}")
    add_subdirectory(${subdir})
    list(APPEND NOCOMPILE_SOURCES "${TEMPLATE_FILE}")
    list(APPEND WEB_RESOURCE_FILES ${SRCS} ${BINARY_SRCS} ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES})
    source_group_by_folder(${SRCS})
    source_group_by_folder(${NOCOMPILE_SOURCES})
    binary_group_by_folder(${BINARY_SRCS} ${NOCOMPILE_BINARIES})
    set_source_files_properties(${SRCS} ${NOCOMPILE_SOURCES} ${NOCOMPILE_BINARIES} PROPERTIES HEADER_FILE_ONLY TRUE)
ENDMACRO()

#intermediatary outputs ARE:
# SRCS = source files to be compiled from the source tree
# BINARY_SRCS = source files to be compiled from the binary tree
# NOCOMPILE_SOURCES = sourcefiles in the source tree that should not be compiled


# FINAL outputs are
# INTERFACE_FILES = files that are part of the (library) interface
# SOURCE_FILES = files that build the library/executable
# TEST_FILES = files that build the test
# DOCUMENTATION_INCLUDE_PATHS - set in the parent scope
# DOCUMENTATION_SOURCE_FILES - set in the parent scope
# DOCUMENTATION_STRIP_FROM_PATHS - set in parent scope
