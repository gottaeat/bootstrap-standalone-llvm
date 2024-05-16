# bootstrap-standalone-llvm
this project builds a complete and standalone llvm suite targeting x86_64 glibc
linux hosts. it has component and feature parity with gcc + binutils + gdb
setups without requiring anything provided by neither gcc nor binutils.

`clang{,++}` by default uses `compiler-rt` and `libunwind` instead of
`libgcc{_s}`, `libc++{,abi}` instead of `libstdc++` and `ld.lld` instead of
`ld.bfd`.

it also installs symlinks to `$ROOT/compat/` to act as drop-in replacements for
corresponding gnu utilities to combat hardcoded calls for `ld`, `gcc`, `g++` or
`cc`, `c++` etc. without requiring source modifications.

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
because `RUNPATH` for all binaries are set `$ORIGIN/../lib` as per llvm cmake
defaults, the path where the toolchain gets placed at does not cause any type of
breakage so setting `LD_LIBRARY_PATH` is not necessary for using components of
the resulting toolchain.

however, if the code being built links against any of the components, such as
c++ code (for `libc++.so.1`) or code that depends on `libgcc` runtime bits
(which we provide via the injected `libclang_rt.builtins.a` and the dynamically
linked `libunwind.so.1`), adding `$ROOT/lib` to `LIBRARY_PATH` and appending
`-I$ROOT/include -L$ROOT/lib` to `{C,LD}FLAGS` might be necessary.

certain cmake projects might force a specific CMAKE_C{,XX}_COMPILER_TARGET and
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
  NEEDED               libLLVM.so.18.1      # self
  NEEDED               libc++.so.1          # self
  NEEDED               libc++abi.so.1       # self
  NEEDED               libc.so.6            # libc
  NEEDED               libclang-cpp.so.18.1 # self
  NEEDED               libffi.so.8          # libffi
  NEEDED               liblldb.so.18.1      # self
  NEEDED               liblzma.so.5         # xz
  NEEDED               libm.so.6            # libc
  NEEDED               libncursesw.so.6     # ncurses
  NEEDED               libpanelw.so.6       # ncurses
  NEEDED               libunwind.so.1       # self
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
