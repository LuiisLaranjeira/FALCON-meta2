cmake_minimum_required(VERSION 2.8.4)

SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Wall -Wextra ${GCC_COVERAGE_COMPILE_FLAGS}" )
IF(UNIX)
 link_libraries(m)
ENDIF(UNIX)

project (falcon) 
SET(EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR})
SET(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR})
SET(RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
SET(CMAKE_BUILD_TYPE Debug)

add_executable (FALCON2 falcon.c mem.c time.c msg.c parser.c common.c buffer.c stream.c levels.c models.c pmodels.c kmodels.c top.c defs.h param.h keys.c filters.c labels.c paint.c
        file_compression.c
        serialization.c
        magnet_integration.c)

TARGET_LINK_LIBRARIES(FALCON2 pthread)
