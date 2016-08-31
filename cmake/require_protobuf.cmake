include (${CMAKE_CURRENT_LIST_DIR}/sanity_download.cmake)
include (${CMAKE_CURRENT_LIST_DIR}/sanity_deduce_version.cmake)

# https://github.com/google/protobuf/archive/v3.0.0-beta-3.tar.gz


function (sanity_require_protobuf given_version)

	#set (versions 3.0.0-beta-3)
	set (versions 8c936063570e5ede2ac41cf49aefe1075f1c7251)
	#set (hashes 89afd3855f2d4782e59c09e07d9efa67)
	set (hashes e9dd2d9750e32ed9f5f2f140fd02d6ba)
	sanity_back(versions latest_version)

	sanity_deduce_version(${given_version} versions protobuf version version_index)
	if (NOT version)
		message (FATAL_ERROR "unable to deduce version")
	endif ()

	if (sanity.require_protobuf.complete)
		return ()
	endif ()

	set (package_name "protobuf-${version}")
	set (source_url "https://github.com/google/protobuf/archive/${version}.tar.gz")
	set (source_gz "${sanity.source.cache.archive}/${package_name}.tar.gz")
	set (tool_build_dir "${sanity.host.build}/${package_name}")
	set (build_dir "${sanity.target.build}/${package_name}")
	list (GET hashes ${version_index} source_hash)

	if (NOT EXISTS ${source_url})
		sanity_download(URL ${source_url} PATH ${source_gz}
						HASH_METHOD MD5
						HASH_EXPECTED ${source_hash}
						ERROR_RESULT result)
		if (result)
			message (FATAL_ERROR "${result}")
		endif ()
	endif ()

	set (source_root "${sanity.target.local.source}")
	set (source_tree "${source_root}/${package_name}")

	sanity_make_flag(untar_flag "target" "${package_name}" "untar")
	if ("${source_gz}" IS_NEWER_THAN "${untar_flag}"
		OR "${source_gz}" IS_NEWER_THAN ${source_tree})
     	execute_process(
			COMMAND ${CMAKE_COMMAND} -E tar xzf ${source_gz}
			WORKING_DIRECTORY ${source_root}
			RESULT_VARIABLE res
	    	)
	    if (res)
	    	message(FATAL_ERROR "error in command tar xzf ${source_gz} : ${res}")
	    endif ()
	    sanity_touch_flag(untar_flag)
 	endif()

 	sanity_make_flag(autogen_flag "target" "${package_name}" "autogen")
 	if (${untar_flag} IS_NEWER_THAN ${autogen_flag})
     	execute_process(COMMAND ./autogen.sh
						WORKING_DIRECTORY ${source_tree}
						RESULT_VARIABLE res)
	    if (res)
	    	message(FATAL_ERROR "error in autogen : ${res}")
	    endif ()
	    sanity_touch_flag(autogen_flag)
 	endif ()

 	sanity_make_flag(configure_tool_flag "host" ${package_name} "configure_tool")
 	if (${untar_flag} IS_NEWER_THAN ${configure_tool_flag} OR NOT EXISTS ${tool_build_dir})
		file (MAKE_DIRECTORY ${tool_build_dir})

		set (configure_args)
		list (APPEND configure_args "--prefix=${sanity.host.local}"
    								"--disable-shared")
    	if (NOT CMAKE_CXX_STANDARD)
    		set (CMAKE_CXX_STANDARD 11)
    	endif ()

		set (cflags "")
		set (cxxflags "")
		set (ldflags "")
		set (libs "")
    	if (APPLE)
    		set (cflags "-DNDEBUG -g -O2 -pipe -fPIC -fcxx-exceptions")
    		set (cxxflags "${cflags} -std=c++${CMAKE_CXX_STANDARD}")
    	else ()
                # Placeholder for other configs
    	endif ()
    	if (cflags)
    		list (APPEND configure_args "CFLAGS=${cflags}")
    	endif ()
    	if (cxxflags)
    		list (APPEND configure_args "CXXFLAGS=${cxxflags}")
    	endif ()
    	if (ldflags)
    		list (APPEND configure_args "LDFLAGS=${ldflags}")
    	endif ()
    	if (libs)
    		list (APPEND configure_args "LIBS=${libs}")
    	endif ()
#    	sanity_join(arg_str " : " ${configure_args})
#    	message (FATAL_ERROR "${configure_args}")
		execute_process(
    		COMMAND "${source_tree}/configure"
    		${configure_args}
    		WORKING_DIRECTORY ${tool_build_dir}
    		RESULT_VARIABLE res
		)
		if (res)
			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
		endif ()



#		set (tool_args 
#				"-DCMAKE_INSTALL_PREFIX=${sanity.host.local}"
#				"-DCMAKE_CXX_FLAGS=-std=c++11"
#				"-Dprotobuf_BUILD_TESTS=OFF")
#
 #		execute_process(COMMAND ${CMAKE_COMMAND}
 #						${tool_args}
 #						${source_tree}/cmake
# 						WORKING_DIRECTORY ${tool_build_dir}
# 						RESULT_VARIABLE res)
#		if (res)
#			message (FATAL_ERROR "configuring tool : error code : ${res}")
#		endif ()
		sanity_touch_flag (configure_tool_flag)
 	endif ()

 	sanity_make_flag(make_tool_flag "host" ${package_name} "make_tool")
 	if (${configure_tool_flag} IS_NEWER_THAN ${make_tool_flag})
 		execute_process(COMMAND make 
 							"-j${sanity.concurrency}"
 							install
 							WORKING_DIRECTORY ${tool_build_dir}
 							RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "making tool : error code : ${res}")
		endif ()
		sanity_touch_flag (make_tool_flag)
 	endif ()

	sanity_make_flag(configure_flag "target" "${package_name}" "configure")
	if (${autogen_flag} IS_NEWER_THAN ${configure_flag} OR NOT EXISTS ${build_dir})
		file (MAKE_DIRECTORY ${build_dir})

		#
		# TODO : configure correctly for IOS etc
		# reference: https://gist.github.com/BennettSmith/9487468ae3375d0db0cc
		#
		set (configure_args)
		list (APPEND configure_args "--prefix=${sanity.target.local}"
    								"--with-protoc=${sanity.host.local}/bin/protoc"
    								"--disable-shared")
    	if (NOT CMAKE_CXX_STANDARD)
    		set (CMAKE_CXX_STANDARD 11)
    	endif ()

		set (cflags "")
		set (cxxflags "")
		set (ldflags "")
		set (libs "")
    	if (APPLE)
    		set (cflags "-DNDEBUG -g -O2 -pipe -fPIC -fcxx-exceptions")
    		set (cflags "${cflags} -arch x86_64 -isystemroot=${macosx_sdk_path}")
    		set (cxxflags "${cflags} -std=c++${CMAKE_CXX_STANDARD}")
			set (ldflags "")
#			set (libs "-lc++ -lc++abi")    		
    		list (APPEND configure_args "--build=x86_64-apple-${sanity.darwin}" 
    									"--host=x86_64-apple-${sanity.darwin}")
    	else ()
		# Placeholder for other configs
    	endif ()
    	if (cflags)
    		list (APPEND configure_args "CFLAGS=${cflags}")
    	endif ()
    	if (cxxflags)
    		list (APPEND configure_args "CXXFLAGS=${cxxflags}")
    	endif ()
    	if (ldflags)
    		list (APPEND configure_args "LDFLAGS=${ldflags}")
    	endif ()
    	if (libs)
    		list (APPEND configure_args "LIBS=${libs}")
    	endif ()
#    	sanity_join(arg_str " : " ${configure_args})
#    	message (FATAL_ERROR "${configure_args}")
		execute_process(
    		COMMAND "${source_tree}/configure"
    		${configure_args}
    		WORKING_DIRECTORY ${build_dir}
    		RESULT_VARIABLE res
		)
		if (res)
			message (FATAL_ERROR "${CMAKE_COMMAND} ${source_tree} : error code : ${res}")
		endif ()
		sanity_touch_flag (configure_flag)
	endif ()

	sanity_make_flag(make_flag "target" "${package_name}" "make")
	if (${configure_flag} IS_NEWER_THAN ${make_flag})
		execute_process(COMMAND make "-j${sanity.concurrency}" 
						install
						WORKING_DIRECTORY ${build_dir}
						RESULT_VARIABLE res)
		if (res)
			message (FATAL_ERROR "failed to make ${package_name}")
		endif ()
		sanity_touch_flag (make_flag)
	endif ()

	set (PROTOBUF_FOUND TRUE)
	set (PROTOBUF_INCLUDE_DIRS ${sanity.target.local}/include)
	set (PROTOBUF_LIBRARIES ${sanity.target.local}/lib/libprotobuf.a)
	set (PROTOBUF_PROTOC_LIBRARIES ${sanity.target.local}/lib/libprotoc.a)
	set (PROTOBUF_LITE_LIBRARIES ${sanity.target.local}/lib/libprotobuf-lite.a)
	set (PROTOBUF_LIBRARY ${sanity.target.local}/lib/libprotobuf.a)
	set (PROTOBUF_PROTOC_LIBRARY ${sanity.target.local}/lib/libprotoc.a)
	set (PROTOBUF_LITE_LIBRARY ${sanity.target.local}/lib/libprotobuf-lite.a)
	set (PROTOBUF_PROTOC_EXECUTABLE ${sanity.host.local}/bin/protoc)

	if (NOT TARGET sanity::protobuf)
		add_library(sanity::protobuf INTERFACE IMPORTED GLOBAL)
		target_link_libraries(sanity::protobuf INTERFACE 
			${PROTOBUF_LIBRARY})
		set_property(TARGET sanity::protobuf 
			APPEND 
			PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${PROTOBUF_INCLUDE_DIRS})
	endif ()

	set (sanity.require_protobuf.complete TRUE)

	sanity_propagate_vars(PROTOBUF_FOUND 
						  PROTOBUF_INCLUDE_DIRS 
						  PROTOBUF_LIBRARIES 
						  PROTOBUF_PROTOC_LIBRARIES
						  PROTOBUF_LITE_LIBRARIES 
						  PROTOBUF_LIBRARY 
						  PROTOBUF_PROTOC_LIBRARY
						  PROTOBUF_LITE_LIBRARY 
						  PROTOBUF_PROTOC_EXECUTABLE 
						  sanity.require_protobuf.complete)

endfunction ()

function (protobuf_configure_files)
	set(options CPP)
	set(oneValueArgs CPP_HEADERS CPP_SOURCES)
	set(multiValueArgs FILES INCLUDES)
	cmake_parse_arguments(ARG "${options}" 
						  "${oneValueArgs}" "${multiValueArgs}"
						  ${ARGN})

	if (NOT ARG_FILES)
		message (FATAL_ERROR "protobuf_configure_files(${ARGN}) : no FILES")
	endif ()

	set (options)
	foreach (incdir IN LISTS ARG_INCLUDES)
		list (APPEND options "--proto_path=${incdir}")
	endforeach ()

	if (ARG_CPP)
		if (NOT ARG_CPP_HEADERS OR NOT ARG_CPP_SOURCES)
			message (FATAL_ERROR "protobuf_configure_files(${ARGN}) : no CPP_HEADERS or CPP_SOURCES")
		endif ()
		set (hdrs)
		set (srcs)
		foreach (proto IN LISTS ARG_FILES)
			get_filename_component (fileroot ${proto} NAME_WE)
			set (hdr "${fileroot}.pb.h")
			set (src "${fileroot}.pb.cc")
			add_custom_command(	OUTPUT ${hdr} ${src} 
								DEPENDS ${proto}
								COMMAND ${PROTOBUF_PROTOC_EXECUTABLE}
								ARGS ${options}
								"--cpp_out=${CMAKE_CURRENT_BINARY_DIR}"
								${proto}
								WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
								COMMENT "build cpp files for ${proto}"
								VERBATIM)

			list (APPEND hdrs "${hdr}")
			list (APPEND srcs "${src}")
		endforeach()

		set (${ARG_CPP_HEADERS} ${hdrs} PARENT_SCOPE)
		set (${ARG_CPP_SOURCES} ${srcs} PARENT_SCOPE)

	endif ()

endfunction ()
