# bootstrap-standalone-llvm
this project builds a complete and standalone llvm suite targeting x86_64 glibc
linux hosts. it has component and feature parity with gcc + binutils + gdb
setups without requiring anything provided by neither gcc nor binutils.

`clang{,++}` by default uses `compiler-rt` and `libunwind` instead of
`libgcc{_s}`, `libc++{,abi}` instead of `libstdc++` and `ld.lld` instead of
`ld.bfd`.

it also installs symlinks to `$ROOT/compat/` to act as drop-in replacements for
corresponding gnu utilities to combat hardcoded calls for `ld`, `gcc`, `g++`
etc. without requiring source modifications.

### components
 - clang
 - compiler-rt
 - libcxx
 - libcxxabi
 - libunwind
 - lld
 - lldb
 - openmp

### warning
as `RUNPATH` for all binaries are set `$ORIGIN/../lib` as per llvm cmake
defaults, the path where the toolchain gets placed at does not cause any type of
breakage so setting `LD_LIBRARY_PATH` is not necessary.

however, if the code being built links against any of the components, such as
c++ code or code that depends on `libgcc` runtime bits, adding `$ROOT/lib` to
`LIBRARY_PATH` and appending `-I$ROOT/include -$ROOT/lib` might be necessary.

in cases where you do link against a component, setting `LD_LIBRARY_PATH` for
runtime and `LIBRARY_PATH` for build time might be necessary, such as the case
of linking `rust` against the `libLLVM-XX` provided with this project.

### runtime dependencies
```sh
$ find . -type f -exec file {} ';' | grep ELF\ 64-bit \
    | awk '{print $1}' | sed 's/:$//g' | xargs objdump -p \
        | grep NEEDED | sort | uniq

NEEDED               ld-linux-x86-64.so.2 # libc
NEEDED               libc.so.6            # libc
NEEDED               libm.so.6            # libc
NEEDED               libffi.so.8          # libffi
NEEDED               libncursesw.so.6     # ncurses
NEEDED               libpanelw.so.6       # ncurses
NEEDED               libLLVM-16.so        # self
NEEDED               libc++abi.so.1       # self
NEEDED               libclang-cpp.so.16   # self
NEEDED               liblldb.so.16        # self
NEEDED               libunwind.so.1       # self
NEEDED               libc++.so.1          # self
NEEDED               liblzma.so.5         # xz
NEEDED               libz.so.1            # zlib
NEEDED               libzstd.so.1         # zstd
```

### example environment setup
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

CPPFLAGS="-DMY_DEF=goodvalue"
CFLAGS="${CPPFLAGS} -O2 -pipe -I${LLVM_PATH}/include -L${LLVM_PATH}/lib"
CXXFLAGS="${CFLAGS}"
LDFLAGS="${CFLAGS} -Wl,--as-needed,--sort-common,-z,relro,-z,now"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
```
