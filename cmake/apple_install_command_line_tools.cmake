if (NOT CMAKE_HOST_APPLE)
	return ()
endif ()

execute_process (COMMAND xcode-select -p
					RESULT_VARIABLE err
					OUTPUT_VARIABLE cout)
if (res EQUAL 2)
	message (STATUS "*** You must install command line tools ***")
	message (STATUS "... downloading virus ...")
	execute_process (COMMAND xcode-select --install
						RESULT_VARIABLE err
						OUTPUT_VARIABLE cout)
	if (err)
		message (FATAL_ERROR "unable to install command line tools.")
		return ()
	endif ()

	execute_process (COMMAND xcode-select -p
						RESULT_VARIABLE err
						OUTPUT_VARIABLE cout)
endif ()

if (err)
	message (FATAL_ERROR "no Xcode command line tools available")
else ()
	message (STATUS "Xcode command line tools : ${cout}")
endif ()


#
# HOMEBREW
#

execute_process (COMMAND brew --version
					RESULT_VARIABLE err
					OUTPUT_VARIABLE cout)
if (err OR sanity.force.homebrew)
	set(sanity.simulate.homebrew FALSE)
	if (NOT err)
		set (sanity.simulate.homebrew TRUE)
	endif ()

	message (STATUS "*** You must install homebrew because macs are a bit shit ***")
	message (STATUS "... downloading virus ...")

	execute_process (COMMAND curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install
						ERROR_VARIABLE cerr
						RESULT_VARIABLE err
						OUTPUT_VARIABLE cout)
	if (err)
		message (STATUS "can't download homebrew")
		message (FATAL_ERROR "${res}\n${cerr}")
	endif ()

	if (sanity.force.homebrew)
		message (STATUS "pretend we ran this:\nruby -e ${cout}")
	else ()
		execute_process (COMMAND ruby
							-e "${cout}"
							ERROR_VARIABLE cerr
							RESULT_VARIABLE err
							OUTPUT_VARIABLE cout)
		if (err)
			message (STATUS "can't install homebrew")
			message (FATAL_ERROR "${res}\n${cerr}")
		endif ()
	endif ()

	execute_process (COMMAND brew update
						ERROR_VARIABLE cerr
						RESULT_VARIABLE err
						OUTPUT_VARIABLE cout)
	if (err)
		message (STATUS "can't update homebrew")
		message (FATAL_ERROR "${res}\n${cerr}")
	endif ()

endif ()

#
# autoconf
#

execute_process (COMMAND autoconf --version
					ERROR_VARIABLE cerr
					RESULT_VARIABLE err
					OUTPUT_VARIABLE cout)
if (err OR sanity.force.homebrew)
	message (STATUS "... installing autoconf")
	execute_process (COMMAND brew install autoconf
				ERROR_VARIABLE cerr
				RESULT_VARIABLE err
				OUTPUT_VARIABLE cout)
	if (err)
		message (STATUS "can't install autoconf")
		message (FATAL_ERROR "${res}\n${cerr}")
	endif ()
endif ()


execute_process (COMMAND glibtool --version
					ERROR_VARIABLE cerr
					RESULT_VARIABLE err
					OUTPUT_VARIABLE cout)
if (err GREATER 1 OR sanity.force.homebrew)
	message (STATUS "... installing glibtool")
	execute_process (COMMAND brew install libtool
				ERROR_VARIABLE cerr
				RESULT_VARIABLE err
				OUTPUT_VARIABLE cout)
	if (err)
		message (STATUS "can't install glibtool")
		message (FATAL_ERROR "${res}\n${cerr}")
	endif ()
endif ()

execute_process (COMMAND automake --version
					ERROR_VARIABLE cerr
					RESULT_VARIABLE err
					OUTPUT_VARIABLE cout)
if (err OR sanity.force.homebrew)
	message (STATUS "... installing automake")
	execute_process (COMMAND brew install automake
				ERROR_VARIABLE cerr
				RESULT_VARIABLE err
				OUTPUT_VARIABLE cout)
	if (err)
		message (STATUS "can't install automake")
		message (FATAL_ERROR "${res}\n${cerr}")
	endif ()
endif ()

