#!/bin/sh
# - - set known state - - #
unset CC CXX LD AR AS NM STRIP RANLIB OBJCOPY OBJDUMP OBJSIZE READELF ADDR2LINE
unset LIBRARY_PATH LD_LIBRARY_PATH

export CPPFLAGS="-DNDEBUG"
export CFLAGS="${CPPFLAGS} -g0 -s -w -pipe -O2"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="${CFLAGS} -Wl,-rpath=. -Wl,--disable-new-dtags"

export MAKEFLAGS="-j$(nproc) V=1"
export SAMUFLAGS="-j$(nproc) -v"

export CARCH="x86_64"
export CHOST="${CARCH}-mss-linux-gnu"
export CBUILD="${CHOST}"

# - - spec - - #
LLVM_VER="16.0.3"

LLVM_RUNTIMES="libunwind;libcxxabi;libcxx"
LLVM_PROJECTS="clang;compiler-rt;lld;lldb;openmp"

. funcs

# - - gather sources - - #
mkdir -pv work/source
if [ ! -f "work/source/llvmorg-${LLVM_VER}.tar.gz" ]; then
    curl -L -o work/source/llvmorg-${LLVM_VER}.tar.gz \
        https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VER}.tar.gz
fi

# - - stage 1 - - #
cd work/
tar xf source/llvmorg-${LLVM_VER}.tar.gz
cd llvm-project-llvmorg-${LLVM_VER}/

for i in ../../patches/*.patch; do
    patch -p1 < "${i}"
done

cleancmake

mkdir build_stage1
cd build_stage1

STAGE1_BUILDDIR="${PWD}"

cmake -Wno-dev -GNinja \
    -DCMAKE_INSTALL_PREFIX="${STAGE1_BUILDDIR}" \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_C_COMPILER_TARGET="$CHOST" \
    -DCMAKE_CXX_COMPILER_TARGET="$CHOST" \
\
    `llvm_base_flags` \
    -DLLVM_ENABLE_LLD=OFF \
    -DLLVM_ENABLE_LIBCXX=OFF \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DCLANG_DEFAULT_LINKER="lld" \
    -DCLANG_DEFAULT_OBJCOPY="llvm-objcopy" \
    -DCLANG_DEFAULT_OPENMP_RUNTIME="libomp" \
    -DCLANG_DEFAULT_RTLIB="compiler-rt" \
    -DCLANG_DEFAULT_UNWINDLIB="libunwind" \
    -DLIBCXXABI_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBCXX_CXX_ABI="libcxxabi" \
    -DLIBCXX_USE_COMPILER_RT=ON \
    -DLIBUNWIND_USE_COMPILER_RT=ON \
    -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=ON \
    -DCOMPILER_RT_USE_BUILTINS_LIBRARY=OFF \
\
    ../llvm

time samu

cd ../

# - - stage 2 - - #
mkdir build_stage2
cd build_stage2

STAGE2_BUILDDIR="${PWD}"

export CC="${STAGE1_BUILDDIR}/bin/clang"
export CXX="${STAGE1_BUILDDIR}/bin/clang++"
export LD="${STAGE1_BUILDDIR}/bin/ld.lld"
export AR="${STAGE1_BUILDDIR}/bin/llvm-ar"
export AS="${STAGE1_BUILDDIR}/bin/clang"
export NM="${STAGE1_BUILDDIR}/bin/llvm-nm"
export STRIP="${STAGE1_BUILDDIR}/bin/llvm-strip"
export RANLIB="${STAGE1_BUILDDIR}/bin/llvm-ranlib"
export OBJCOPY="${STAGE1_BUILDDIR}/bin/llvm-objcopy"
export OBJDUMP="${STAGE1_BUILDDIR}/bin/llvm-objdump"
export OBJSIZE="${STAGE1_BUILDDIR}/bin/llvm-size"
export READELF="${STAGE1_BUILDDIR}/bin/llvm-readelf"
export ADDR2LINE="${STAGE1_BUILDDIR}/bin/llvm-addr2line"

CPPFLAGS="-DNDEBUG -D_FORTIFY_SOURCE=2"
CFLAGS="${CPPFLAGS} -g0 -s -w -pipe -O3 -march=x86-64 -mtune=generic"
CFLAGS="${CFLAGS} -fcommon -fstack-protector-strong -flto-jobs=4 -flto=thin"
CFLAGS="${CFLAGS} -fuse-ld=lld -stdlib=libc++"
CFLAGS="${CFLAGS} -rtlib=compiler-rt -unwindlib=libunwind"
CFLAGS="${CFLAGS} -I${STAGE1_BUILDDIR}/include -L${STAGE1_BUILDDIR}/lib"
CXXFLAGS="${CFLAGS}"
LDFLAGS="${CFLAGS} -Wl,--as-needed,--sort-common,-z,relro,-z,now"
LDFLAGS="${LDFLAGS} -Wl,--gc-sections,-O3,--icf=all"
LDFLAGS="${LDFLAGS} -Wl,--lto-O3,--thinlto-jobs=4"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

export LD_LIBRARY_PATH="${STAGE2_BUILDDIR}/lib:${STAGE1_BUILDDIR}/lib"

RELEASE_DIR="${PWD}"/release

cmake -Wno-dev -GNinja \
    -DCMAKE_INSTALL_PREFIX="${RELEASE_DIR}" \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_AR="$AR" \
    -DCMAKE_NM="$NM" \
    -DCMAKE_STRIP="$STRIP" \
    -DCMAKE_RANLIB="$RANLIB" \
    -DCMAKE_LINKER="$LD" \
    -DCMAKE_OBJCOPY="$OBJCOPY" \
    -DCMAKE_OBJDUMP="$OBJDUMP" \
    -DCMAKE_READELF="$READELF" \
    -DCMAKE_ADDR2LINE="$ADDR2LINE" \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_COMPILER_TARGET="$CHOST" \
    -DCMAKE_CXX_COMPILER_TARGET="$CHOST" \
\
    `llvm_base_flags` \
    -DLLVM_ENABLE_LTO=Thin \
    -DLLVM_PARALLEL_LINK_JOBS="4" \
    -DLLVM_ENABLE_LLD=ON \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_OPTIMIZED_TABLEGEN=OFF \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DCLANG_DEFAULT_LINKER="lld" \
    -DCLANG_DEFAULT_OBJCOPY="llvm-objcopy" \
    -DCLANG_DEFAULT_OPENMP_RUNTIME="libomp" \
    -DCLANG_DEFAULT_RTLIB="compiler-rt" \
    -DCLANG_DEFAULT_UNWINDLIB="libunwind" \
    -DLIBCXXABI_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBCXX_CXX_ABI="libcxxabi" \
    -DLIBCXX_USE_COMPILER_RT=ON \
    -DLIBUNWIND_USE_COMPILER_RT=ON \
    -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF \
    -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
\
    ../llvm

time samu
samu install

# - - strip + debloat - - #
find "${RELEASE_DIR}" -type f \
    \( -name \*.a -a \
        ! -name libclang_rt\* \
        ! -name libunwind.a \
    \) \
        -exec rm -rfv {} ';'

rm -rfv "${RELEASE_DIR}"/share

find "${RELEASE_DIR}"/bin -type f -exec strip --strip-all {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.a -exec strip --strip-debug {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.a -exec "${RANLIB}" {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'

# - - create compat symlinks - - #
mkdir "${RELEASE_DIR}"/compat
pushd "${RELEASE_DIR}"/compat

ln -sfv ../bin/llvm-symbolizer addr2line
ln -sfv ../bin/llvm-ar         ar
ln -sfv ../bin/clang-16        as
ln -sfv ../bin/clang-16        c++
ln -sfv ../bin/llvm-cxxfilt    c++filt
ln -sfv ../bin/clang-16        cc
ln -sfv ../bin/clang-16        cpp
ln -sfv ../bin/clang-16        g++
ln -sfv ../bin/clang-16        gcc
ln -sfv ../bin/llvm-cov        gcov
ln -sfv ../bin/lld             ld
ln -sfv ../bin/llvm-nm         nm
ln -sfv ../bin/llvm-objcopy    objcopy
ln -sfv ../bin/llvm-objdump    objdump
ln -sfv ../bin/llvm-ar         ranlib
ln -sfv ../bin/llvm-readobj    readelf
ln -sfv ../bin/llvm-size       size
ln -sfv ../bin/llvm-strings    strings
ln -sfv ../bin/llvm-objcopy    strip

popd

# - - package - - #
tar \
    --numeric-owner \
    --preserve-permissions \
    --create --zstd -C "${RELEASE_DIR}"/../ \
    --file=../../../llvm-standalone-"${LLVM_VER}"-"$(date '+%Y%m%d_%H%M%S')".tar.zst \
    "release"

cd ../../../
rm -rf work/
