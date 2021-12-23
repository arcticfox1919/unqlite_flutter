@echo off 

set SDK=C:\Users\Administrator\AppData\Local\Android\Sdk
set NDK=%SDK%\ndk\24.0.7956693
set NINJA=%SDK%\cmake\3.10.2.4988404\bin\ninja

set MINSDKVERSION=21

setlocal enabledelayedexpansion 
set ABI=armeabi-v7a


cd build

set ABI_LIST=armeabi-v7a arm64-v8a x86_64

(for %%a in (%ABI_LIST%) do ( 
	set ABI=%%a
	cmake ^
	-DCMAKE_SYSTEM_NAME=Android ^
	-DCMAKE_SYSTEM_VERSION=%MINSDKVERSION% ^
	-DANDROID_PLATFORM=android-%MINSDKVERSION% ^
	-DCMAKE_ANDROID_ARCH_ABI=!ABI! ^
	-DCMAKE_ANDROID_NDK=%NDK% ^
	-DCMAKE_TOOLCHAIN_FILE=%NDK%\build\cmake\android.toolchain.cmake ^
	-DCMAKE_MAKE_PROGRAM=%NINJA% ^
	-DCMAKE_BUILD_TYPE=Release ^
	-G "Ninja" ..

	%NINJA%
	
	del .\*.* /q
))

