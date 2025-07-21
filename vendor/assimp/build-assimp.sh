#!/bin/bash

# Building statically gives us all kinds of linking horrors

cmake CMakeLists.txt -G "Visual Studio 17 2022" -A x64 \
    -D ASSIMP_WARNINGS_AS_ERRORS=ON \
    -D ASSIMP_BUILD_ASSIMP_TOOLS=OFF \
    -D BUILD_SHARED_LIBS=ON \
    -D ASSIMP_BUILD_ZLIB=ON \
    -D ASSIMP_BUILD_TESTS=OFF \
    -D ASSIMP_INSTALL=OFF \
    -D USE_STATIC_CRT=OFF \
    -D ASSIMP_BUILD_ASSIMP_VIEW=OFF

cmake --build . --config release --parallel 10
