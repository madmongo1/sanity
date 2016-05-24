if (sanity.function.sanity_deduce_apple.included)
	return ()
endif ()
set (sanity.function.sanity_deduce_apple.included TRUE)

function (sanity_deduce_darwin_bits platform)
	if (NOT ${platform}_sdk_platform_path)
		execute_process (	COMMAND xcrun --sdk ${platform} --show-sdk-platform-path
							OUTPUT_STRIP_TRAILING_WHITESPACE
							RESULT_VARIABLE res
							OUTPUT_VARIABLE ${platform}_sdk_platform_path)
		if (res)
			message (FATAL_ERROR "failed to deduce ${platform}_sdk_platform_path : ${res}")
		else ()
			set (${platform}_sdk_platform_path ${${platform}_sdk_platform_path} CACHE PATH "${platform}_sdk_platform_path")
		endif ()
	endif ()

	if (NOT ${platform}_sdk_version)
		execute_process (	COMMAND xcrun --sdk ${platform} --show-sdk-version
							OUTPUT_STRIP_TRAILING_WHITESPACE
							RESULT_VARIABLE res
							OUTPUT_VARIABLE ${platform}_sdk_version)
		if (res)
			message (FATAL_ERROR "failed to deduce ${platform}_sdk_version : ${res}")
		else ()
			set (${platform}_sdk_version ${${platform}_sdk_version} CACHE PATH "${platform}_sdk_version")
		endif ()
	endif ()

	if (NOT ${platform}_sdk_path)
		execute_process (	COMMAND xcrun --sdk ${platform} --show-sdk-path
							OUTPUT_STRIP_TRAILING_WHITESPACE
							RESULT_VARIABLE res
							OUTPUT_VARIABLE ${platform}_sdk_path)
		if (res)
			message (FATAL_ERROR "failed to deduce ${platform}_sdk_path : ${res}")
		else ()
			set (${platform}_sdk_path ${${platform}_sdk_path} CACHE PATH "${platform}_sdk_path")
		endif ()
	endif ()

	message ("${platform}_sdk_platform_path           : ${${platform}_sdk_platform_path}")
	message ("${platform}_sdk_version                 : ${${platform}_sdk_version}")
	message ("${platform}_sdk_path                    : ${${platform}_sdk_path}")

endfunction ()

function (sanity_deduce_darwin_toolset)
	if (NOT sanity.darwin)
		set (sanity.darwin "darwin14.0.0" CACHE STRING "darwin15.0.0 = El Capitan. darwin14.0.0 = Yosemite")
	endif ()
	if (NOT macosx_min_sdk_version)
		set (macosx_min_sdk_version "8.3" CACHE STRING "macosx_min_sdk_version")
	endif ()
	if (NOT xcode_dir)
		execute_process (	COMMAND xcode-select 
								--print-path
							RESULT_VARIABLE res
							OUTPUT_VARIABLE xcode_dir
							OUTPUT_STRIP_TRAILING_WHITESPACE)
		if (res)
			message (FATAL_ERROR "error in print-path : ${res1}")
		else ()
			set(xcode_dir CACHE PATH "xcode root")
		endif ()
	endif ()

	message ("sanity.darwin                      : ${sanity.darwin}")
	message ("xcode_dir                          : ${xcode_dir}")
	message ("macosx_min_sdk_version             : ${macosx_min_sdk_version}")

	sanity_deduce_darwin_bits(macosx)
	sanity_deduce_darwin_bits(iphoneos)
	sanity_deduce_darwin_bits(iphonesimulator)

endfunction ()
