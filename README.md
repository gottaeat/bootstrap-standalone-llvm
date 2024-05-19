# bootstrap-standalone-llvm
this project builds a complete and standalone llvm suite targeting x86_64 glibc
linux hosts and has component and feature parity with traditional gcc +
binutils + gdb setups. it requires nothing provided by neither gcc nor binutils,
and has no runtime dependencies except for glibc.

### components
 - clang
 - compiler-rt
 - libcxx 
 - libcxxabi
 - libunwind
 - lld
 - lldb
 - openmp

`clang{,++}` provided by default uses `compiler-rt` and `libunwind` instead of
`libgcc{_s}`, `libc++{,abi}` instead of `libstdc++` and `ld.lld` instead of
`ld.bfd`.

there also symlinks installed to `$ROOT/compat/` to act as drop-in replacements
for corresponding gnu utilities to combat hardcoded calls for `ld`, `gcc`, `g++`
or `cc`, `c++` etc. without requiring source modifications.

`libc++` (which is linked against `libc++abi` statically, which itself is
statically linked against `libunwind`), `libunwind`, and `libomp` (openmp) are
provided in static library forms to remove the existence of the toolchain as
runtime dependency.

`libLLVM`, `libclang*`, `liblld*` and `liblldb*` are left as shared libraries
to allow for projects such as rust to be built with it or for module support to
be possible.

### building
#### host
simply run `./build.sh` in the root directory of this repo. it is assumed that
you have the build requirements, if not the case, peep into the `Dockerfile`.

#### docker
this simply installs build-time dependencies and runs `build.sh` inside whatever
the latest debian version is.
```
docker compose run --build=true \
    bootstrap-llvm \
    /bin/bash -c './build.sh' --build
```

however you may have chosen to proceed, you should have a tarball in `out/` in
the root of this repo.

### warning
because `RUNPATH` for all binaries are set `$ORIGIN/../lib` as per llvm cmake
defaults, the path where the toolchain gets placed at does not cause any type of
breakage so setting `LD_LIBRARY_PATH` is not necessary for using components of
the resulting toolchain.

however, setting `LIBRARY_PATH` to `$ROOT/lib` and `-I$ROOT/include -L$ROOT/lib`
to `{C,LD}FLAGS` during build-time, and setting `LD_LIBRARY_PATH` to `$ROOT/lib`
during runtime in cases where you link against the shared libraries provided is
necessary.

certain cmake projects might force a specific `CMAKE_C{,XX}_COMPILER_TARGET` and
this may result in cmake exiting during c{,++} compiler sanity checks. this is
due to this project having compiled the clang runtime for the
`x86_64-mss-linux-gnu` target triple:
```sh
# default behavior
$ clang -print-libgcc-file-name
/release/lib/clang/18/lib/x86_64-mss-linux-gnu/libclang_rt.builtins.a
#                         ^^^^^^^^^^^^^^^^^^^^             ^^^^^^^^

# when --target is specified
$ clang --target=x86_64-unknown-linux-gnu -print-libgcc-file-name
/release/lib/clang/18/lib/linux/libclang_rt.builtins-x86_64.a
#                         ^^^^^             ^^^^^^^^^^^^^^^
```
simply setting `-DCMAKE_C_COMPILER_TARGET` and `-DCMAKE_CXX_COMPILER_TARGET` to
`x86_64-mss-linux-gnu` will fix this.

### runtime dependencies
```sh
$ find . -type f -exec file {} ';' | grep ELF\ 64-bit \
    | awk '{print $1}' | sed 's/:$//g' | xargs objdump -p \
        | grep NEEDED | sort | uniq
  NEEDED               ld-linux-x86-64.so.2 # libc
  NEEDED               libclang-cpp.so.18.1 # self
  NEEDED               libc.so.6            # libc
  NEEDED               liblldb.so.18.1      # self
  NEEDED               libLLVM.so.18.1      # self
  NEEDED               libm.so.6            # libc
```

### example build-time and runtime environment setup
```sh
LLVM_PATH="/path/to/release"

PATH="${LLVM_PATH}/bin:${LLVM_PATH}/compat:${PATH}"
LD_LIBRARY_PATH="${LLVM_PATH}/lib:${LD_LIBRARY_PATH}"
LIBRARY_PATH="${LLVM_PATH}/lib:${LIBRARY_PATH}"
export PATH LD_LIBRARY_PATH LIBRARY_PATH

CC="${LLVM_PATH}/bin/clang"
CXX="${LLVM_PATH}/bin/clang++"
LD="${LLVM_PATH}/bin/ld.lld"
AR="${LLVM_PATH}/bin/llvm-ar"
AS="${LLVM_PATH}/bin/clang"
NM="${LLVM_PATH}/bin/llvm-nm"
STRIP="${LLVM_PATH}/bin/llvm-strip"
RANLIB="${LLVM_PATH}/bin/llvm-ranlib"
OBJCOPY="${LLVM_PATH}/bin/llvm-objcopy"
OBJDUMP="${LLVM_PATH}/bin/llvm-objdump"
OBJSIZE="${LLVM_PATH}/bin/llvm-size"
READELF="${LLVM_PATH}/bin/llvm-readelf"
ADDR2LINE="${LLVM_PATH}/bin/llvm-addr2line"
export CC CXX LD AR AS NM STRIP RANLIB OBJCOPY OBJDUMP OBJSIZE READELF ADDR2LINE

CPPFLAGS="-DMYDEF=MYVAL"
CFLAGS="${CPPFLAGS} -O2 -pipe -I${LLVM_PATH}/include -L${LLVM_PATH}/lib"
CXXFLAGS="${CFLAGS}"
LDFLAGS="${CFLAGS} -Wl,--as-needed,--sort-common,-z,relro,-z,now"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
```
