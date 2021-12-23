cmake_minimum_required(VERSION 3.4.1)

project(unqlite)

include_directories(${CMAKE_CURRENT_LIST_DIR}/src)

add_definitions(-DJX9_DISABLE_BUILTIN_FUNC -DJX9_DISABLE_DISK_IO)

set(HEADERS_UNQLITE
  unqlite.h
)

set(SOURCES_UNQLITE
  unqlite.c
)

# add "strip" flag,remove debug symbols and reduce library size
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")

# set the output path of the library
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG
        ${PROJECT_SOURCE_DIR}/../../../../../build/debug/${ANDROID_ABI})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE
        ${CMAKE_BINARY_DIR}/../../../../../build/release/${ANDROID_ABI})

set(UNQLITE_LIB unqlite)
add_library(${UNQLITE_LIB} SHARED ${HEADERS_UNQLITE} ${SOURCES_UNQLITE})

