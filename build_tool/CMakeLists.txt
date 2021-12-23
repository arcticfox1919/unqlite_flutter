cmake_minimum_required(VERSION 3.4.1)

project(unqlite)

set(SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/../unqlite-1.1.9)

include_directories(${SRC_DIR}/src)

# see:https://unqlite.org/c_api_const.html#compile_time
add_definitions(-DJX9_DISABLE_BUILTIN_FUNC -DJX9_DISABLE_DISK_IO)

set(HEADERS_UNQLITE ${SRC_DIR}/unqlite.h)
set(SOURCES_UNQLITE ${SRC_DIR}/unqlite.c)
set(UNQLITE_LIB unqlite)

# add "strip" flag,remove debug symbols and reduce library size
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")

# set the output path of the library
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG
        ${CMAKE_CURRENT_LIST_DIR}/output/debug/${ANDROID_ABI})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE
        ${CMAKE_CURRENT_LIST_DIR}/output/release/${ANDROID_ABI})


add_library(${UNQLITE_LIB} SHARED ${HEADERS_UNQLITE} ${SOURCES_UNQLITE})
