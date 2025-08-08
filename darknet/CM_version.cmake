# Darknet object detection framework


# Create a version string from the git tag and commit hash (see src/darknet_version.h.in).
# Should look similar to this:
#
#		v1.99-63-gc5c3569
#

# Try to get version from git, if that fails use VERSION file
EXECUTE_PROCESS (COMMAND git describe --tags --dirty OUTPUT_VARIABLE DARKNET_VERSION_STRING OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)

IF (NOT DARKNET_VERSION_STRING)
    # Not in a git repo, try to read from VERSION file
    IF (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
        FILE(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" DARKNET_VERSION_STRING)
        STRING(STRIP "${DARKNET_VERSION_STRING}" DARKNET_VERSION_STRING)
    ELSE()
        # Fallback to a default version
        SET(DARKNET_VERSION_STRING "v3.0.53")
    ENDIF()
ENDIF()

MESSAGE (STATUS "Darknet ${DARKNET_VERSION_STRING}")

# Try to parse version string
STRING (REGEX MATCH "v([0-9]+)\.([0-9]+)\.?([0-9]*)" _ ${DARKNET_VERSION_STRING})

# Set version components with defaults if not found
IF (CMAKE_MATCH_1)
    SET (DARKNET_VERSION_SHORT ${CMAKE_MATCH_1}.${CMAKE_MATCH_2})
    IF (CMAKE_MATCH_3)
        SET (DARKNET_VERSION_SHORT ${DARKNET_VERSION_SHORT}.${CMAKE_MATCH_3})
    ELSE()
        SET (DARKNET_VERSION_SHORT ${DARKNET_VERSION_SHORT}.0)
    ENDIF()
ELSE()
    SET (DARKNET_VERSION_SHORT "3.0.53")
ENDIF()

# Get branch name if in git, otherwise use "main"
EXECUTE_PROCESS (COMMAND git branch --show-current OUTPUT_VARIABLE DARKNET_BRANCH_NAME OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
IF (NOT DARKNET_BRANCH_NAME)
    SET (DARKNET_BRANCH_NAME "main")
ENDIF()
MESSAGE (STATUS "Darknet branch name: ${DARKNET_BRANCH_NAME}")
