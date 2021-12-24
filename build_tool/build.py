
import os,sys,shutil

def clean(filepath): 
    del_list = os.listdir(filepath) 
    for f in del_list: 
        file_path = os.path.join(filepath, f) 
        if os.path.isfile(file_path): 
            os.remove(file_path) 
        elif os.path.isdir(file_path): 
            shutil.rmtree(file_path) 


# MacOS: android sdk and ndk path
SDK='~/Library/Android/sdk'
NDK=f'{SDK}/ndk/23.1.7779620'
NINJA='/usr/local/bin/ninja'
MINSDKVERSION=21

# root path of the current script
root_path = os.path.dirname(os.path.abspath(__file__))

IOS_ARCHS = [('SIMULATOR64','x86_64'),('OS64','arm64'),('OS','armv7')]

IOS_OUT = f'{root_path}/output/ios/release'
IOS_FRAMEWORK = 'unqlite.framework'
LIB = 'unqlite'

ANDROID_ARCHS = ["x86_64","armeabi-v7a","arm64-v8a" ]

print('''
1. For iOS platform
2. For Android platform
3. Clean build 
''')

no_type = input('Please select the target number(for example:1 or 2):')

if not os.path.exists('build'):
    os.mkdir('build')

os.chdir(f'{root_path}/build')
if int(no_type) == 1: # iOS Platform
    for platform,arch in IOS_ARCHS:
        cmd = f'cmake .. -G Xcode -DCMAKE_TOOLCHAIN_FILE={root_path}/ios.toolchain.cmake -DPLATFORM={platform} \
            -DARCHS={arch} -DPLATFORM_IOS=ON -Bios-cache/{arch} -DDEPLOYMENT_TARGET=9.0'

        os.system(cmd)
        os.chdir(f'ios-cache/{arch}')
        os.system('cmake --build . --config Release')
        os.chdir('../..')

    if not os.path.exists(f'{root_path}/output/ios/fat/{IOS_FRAMEWORK}'):
        shutil.copytree(f'{IOS_OUT}/arm64/{IOS_FRAMEWORK}',f'{root_path}/output/ios/fat/{IOS_FRAMEWORK}')

    os.system(f'lipo -create {IOS_OUT}/arm64/{IOS_FRAMEWORK}/{LIB} \
        {IOS_OUT}/armv7/{IOS_FRAMEWORK}/{LIB} \
        {IOS_OUT}/x86_64/{IOS_FRAMEWORK}/{LIB} -output \
        {root_path}/output/ios/fat/{IOS_FRAMEWORK}/{LIB}')
elif int(no_type) == 2:
    for ABI in ANDROID_ARCHS:
        cmd = f'cmake -DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION={MINSDKVERSION} \
            -DANDROID_PLATFORM=android-{MINSDKVERSION} -DCMAKE_ANDROID_ARCH_ABI={ABI} \
            -DCMAKE_ANDROID_NDK={NDK} -DCMAKE_TOOLCHAIN_FILE={NDK}/build/cmake/android.toolchain.cmake \
            -DCMAKE_MAKE_PROGRAM={NINJA} -DCMAKE_BUILD_TYPE=Release -Bandroid-cache/{ABI} -GNinja  ..'

        os.system(cmd)
        os.chdir(f'android-cache/{ABI}')
        os.system('cmake --build . --config Release')
        os.chdir('../..')
else :
    clean(f'{root_path}/build')


