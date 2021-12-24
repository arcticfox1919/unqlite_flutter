cmake_minimum_required(VERSION 3.12.0)

project(unqlite)

set(SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/../unqlite-1.1.9)
set(ARCHS "x86_64" CACHE STRING "CPU Architecture")
option(PLATFORM_IOS "the system platform" OFF)

# see:https://unqlite.org/c_api_const.html#compile_time
add_definitions(-DJX9_DISABLE_BUILTIN_FUNC -DJX9_DISABLE_DISK_IO)

set(HEADERS_UNQLITE ${SRC_DIR}/unqlite.h)
set(SOURCES_UNQLITE ${SRC_DIR}/unqlite.c)
set(UNQLITE_LIB unqlite)

# add "strip" flag,remove debug symbols and reduce library size
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -Oz")

# set the output path of the library
if(PLATFORM_IOS)
    # set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_CURRENT_LIST_DIR}/output/ios/debug/${ARCHS})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_CURRENT_LIST_DIR}/output/ios/release/${ARCHS})
    set(LIB_TYPE STATIC)
else()  # Android
    # set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_CURRENT_LIST_DIR}/output/android/debug/${ANDROID_ABI})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE ${CMAKE_CURRENT_LIST_DIR}/output/android/release/${ANDROID_ABI})
    set(LIB_TYPE SHARED)
endif()

include_directories(${SRC_DIR}/src)
add_library(${UNQLITE_LIB} ${LIB_TYPE} ${HEADERS_UNQLITE} ${SOURCES_UNQLITE} ${CMAKE_CURRENT_LIST_DIR}/config.c)

if(PLATFORM_IOS)
    set_target_properties(unqlite PROPERTIES
        FRAMEWORK TRUE 
        FRAMEWORK_VERSION A 
        MACOSX_FRAMEWORK_IDENTIFIER bczl.xyz 
        VERSION 0.0.1 
        SOVERSION 0.0.1 
        PUBLIC_HEADER ${HEADERS_UNQLITE}
    )
endif()