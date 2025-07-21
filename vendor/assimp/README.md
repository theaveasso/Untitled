# jassimp

Jai bindings for the C API of [Assimp](https://github.com/assimp/assimp) `v6.0.2`.

We have only generated bindings for Windows, but PR welcome for other platforms.

To use, import this package (you don't need the include folder or generate.jai file) and
ensure you have the `assimp-vc143-mt.dll` next to your executable.

Note: zlib is required, and so is built with assimp and statically linked.
