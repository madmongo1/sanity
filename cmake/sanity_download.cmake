if (sanity.function.sanity_download.included)
	return ()
endif ()
set (sanity.function.sanity_download.included TRUE)

function (sanity_actual_download url path status_out)

	file(DOWNLOAD ${url} 
		${path} 
		SHOW_PROGRESS
		STATUS status)
     list (GET status 0 code)
     if (code EQUAL 35)
	     execute_process(COMMAND curl "${url}" -o "${path}" RESULT_VARIABLE res)
	     if (res)
	     	set (status "100" "even curl failed ${res}")
	     else ()
	     	set (status "0" "used curl")
	     endif ()

     endif ()

     set (${status_out} ${status} PARENT_SCOPE)

endfunction ()

function (sanity_download)
	set(options)
	set(oneValueArgs URL PATH HASH_METHOD HASH_EXPECTED ERROR_RESULT)
	set(multiValueArgs)
	cmake_parse_arguments(SANITY_DOWNLOAD "${options}" 
						  "${oneValueArgs}" "${multiValueArgs}"
						  ${ARGN})

	if (NOT SANITY_DOWNLOAD_ERROR_RESULT)
		set (msg "sanity_download(${ARGN}) - missing ERROR_RESULT")
#		set (${SANITY_DOWNLOAD_ERROR_RESULT} "${msg}" PARENT_SCOPE)
		message (FATAL_ERROR "${msg}")
	endif ()

	if (NOT SANITY_DOWNLOAD_URL)
		set (msg "sanity_download(${ARGN}) - missing URL")
		set (${SANITY_DOWNLOAD_ERROR_RESULT} "${msg}" PARENT_SCOPE)
		message (FATAL_ERROR "${msg}")
	endif ()

	if (NOT SANITY_DOWNLOAD_PATH)
		set (msg "sanity_download(${ARGN}) - missing PATH")
		set (${SANITY_DOWNLOAD_ERROR_RESULT} "${msg}" PARENT_SCOPE)
		message (FATAL_ERROR "${msg}")
	endif ()

	if (NOT SANITY_DOWNLOAD_HASH_METHOD)
		set (msg "sanity_download(${ARGN}) - missing HASH_METHOD")
		set (${SANITY_DOWNLOAD_ERROR_RESULT} "${msg}" PARENT_SCOPE)
		message (FATAL_ERROR "${msg}")
	endif ()

	if (NOT SANITY_DOWNLOAD_HASH_EXPECTED)
		set (msg "sanity_download(${ARGN}) - missing HASH_EXPECTED")
		set (${SANITY_DOWNLOAD_ERROR_RESULT} "${msg}" PARENT_SCOPE)
		message (FATAL_ERROR "${msg}")
	endif ()

	if (NOT EXISTS ${SANITY_DOWNLOAD_PATH})
		sanity_actual_download (${SANITY_DOWNLOAD_URL} 
							${SANITY_DOWNLOAD_PATH}
							status)
#		file(DOWNLOAD ${SANITY_DOWNLOAD_URL} 
#			${SANITY_DOWNLOAD_PATH} 
#			SHOW_PROGRESS
#			STATUS status
#	     )
	     list (GET status 0 status_code)
	     list (GET status 1 status_string)
	     if (NOT status_code EQUAL 0)
	     	file (REMOVE ${SANITY_DOWNLOAD_PATH})
			set (${SANITY_DOWNLOAD_ERROR_RESULT} "download failed" PARENT_SCOPE)
			message(FATAL_ERROR 
"error downloading.
url          : ${SANITY_DOWNLOAD_URL}
path         : ${SANITY_DOWNLOAD_PATH}
status_code  : ${status_code}
status_string: ${status_string}
log          : ${log}
")
		endif ()
		file (${SANITY_DOWNLOAD_HASH_METHOD} ${SANITY_DOWNLOAD_PATH} hashcode)
		if (NOT hashcode STREQUAL SANITY_DOWNLOAD_HASH_EXPECTED)
	     	file (REMOVE ${SANITY_DOWNLOAD_PATH})
			set (${SANITY_DOWNLOAD_ERROR_RESULT} "wrong hash" PARENT_SCOPE)
			message(FATAL_ERROR 
"MD5 hash mismatch
url: ${SANITY_DOWNLOAD_URL}
file: ${SANITY_DOWNLOAD_PATH}
expected: ${SANITY_DOWNLOAD_HASH_EXPECTED}
actual: ${hashcode}
")
		endif ()
     endif ()


endfunction ()
