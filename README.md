# bootstrap-standalone-llvm
this project builds a complete and self hosting LLVM suite. it targets GLIBC
Linux hosts. it has component and feature parity with a GCC + Binutils setup
without requiring anything provided by neither gcc nor binutils. it also
installs symlinks in `compat/` to act as drop-in replacements for corresponding
GNU utilities.

`RUNPATH` for binaries are set `$ORIGIN/../lib` for making the toolchain
portable.

due to their massive size, static libraries are removed from builds however
tooling that requires LLVM can still be built with and linked against this
build without issues.

### components
 - clang
 - compiler-rt
 - libcxx
 - libcxxabi
 - libunwind
 - lld
 - lldb
 - openmp

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
