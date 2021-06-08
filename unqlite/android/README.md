# Compiling UnQLite for Android

First, install the NDK development environment in Android Studio, including the cmake tool.



Run the command in the project root directory：

```shell
gradlew assembleRelease
```

The release version of the dynamic library will be generated in the `build/release` directory.

The debug version can be generated with the `gradlew assembleDebug` command.

