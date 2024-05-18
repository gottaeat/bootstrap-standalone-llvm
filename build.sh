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
LLVM_VER="18.1.5"
LIBFFI_VER="3.4.6"
XZ_VER="5.4.6"
NCURSES_VER="6.5"
ZLIB_VER="1.3.1"
ZSTD_VER="1.5.6"

LLVM_RUNTIMES="libunwind;libcxxabi;libcxx"
LLVM_PROJECTS="clang;compiler-rt;lld;lldb;openmp"

. ./funcs

# - - gather sources - - #
mkdir -pv work/source

if [ ! -f "work/source/llvmorg-${LLVM_VER}.tar.gz" ]; then
    curl -L -o work/source/llvmorg-${LLVM_VER}.tar.gz \
        https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VER}.tar.gz
fi

if [ ! -f "work/source/libffi-${LIBFFI_VER}.tar.gz" ]; then
    curl -L -o work/source/libffi-${LIBFFI_VER}.tar.gz \
        https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz
fi

if [ ! -f "work/source/xz-${XZ_VER}.tar.xz" ]; then
    curl -L -o "work/source/xz-${XZ_VER}.tar.xz" \
        https://github.com/tukaani-project/xz/releases/download/v${XZ_VER}/xz-${XZ_VER}.tar.xz
fi

if [ ! -f "work/source/xz-${XZ_VER}.tar.xz" ]; then
    curl -L -o "work/source/xz-${XZ_VER}.tar.xz" \
        https://github.com/tukaani-project/xz/releases/download/v${XZ_VER}/xz-${XZ_VER}.tar.xz
fi

if [ ! -f "work/source/ncurses-${NCURSES_VER}.tar.gz" ]; then
    curl -L -o "work/source/ncurses-${NCURSES_VER}.tar.gz" \
        https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VER}.tar.gz
fi

if [ ! -f "work/source/zlib-${ZLIB_VER}.tar.gz" ]; then
    curl -L -o "work/source/zlib-${ZLIB_VER}.tar.gz" \
        https://github.com/madler/zlib/releases/download/v${ZLIB_VER}/zlib-${ZLIB_VER}.tar.gz
fi

if [ ! -f "work/source/zstd-${ZSTD_VER}.tar.gz" ]; then
    curl -L -o "work/source/zstd-${ZSTD_VER}.tar.gz" \
        https://github.com/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz
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
    -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=ON \
    -DCOMPILER_RT_USE_BUILTINS_LIBRARY=OFF \
\
    ../llvm

time samu

cd ../../

# - - static deps - - #
EXTERNAL_LIBDIR="${PWD}/3rdparty"
STAGE2_BUILDDIR="${PWD}/llvm-project-llvmorg-${LLVM_VER}/build_stage2"

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
CFLAGS="${CPPFLAGS} -g0 -s -w -pipe -O3 -march=x86-64 -mtune=generic -fPIC"
CFLAGS="${CFLAGS} -fcommon -fstack-protector-strong -flto-jobs=8 -flto=thin"
CFLAGS="${CFLAGS} -I${STAGE1_BUILDDIR}/include -L${STAGE1_BUILDDIR}/lib"
CFLAGS="${CFLAGS} -I${EXTERNAL_LIBDIR}/include -L${EXTERNAL_LIBDIR}/lib"
CXXFLAGS="${CFLAGS}"
LDFLAGS="${CFLAGS} -Wl,--as-needed,--sort-common,-z,relro,-z,now"
LDFLAGS="${LDFLAGS} -Wl,--gc-sections,-O3,--icf=all"
LDFLAGS="${LDFLAGS} -Wl,--lto-O3,--thinlto-jobs=8"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS

PATH="${EXTERNAL_LIBDIR}/bin:${PATH}"
LD_LIBRARY_PATH="${STAGE2_BUILDDIR}/lib:${STAGE1_BUILDDIR}/lib"
LIBRARY_PATH="${EXTERNAL_LIBDIR}/lib"
PKG_CONFIG_PATH="${EXTERNAL_LIBDIR}/lib/pkgconfig"
export PATH LD_LIBRARY_PATH LIBRARY_PATH PKG_CONFIG_PATH

# - - libffi - - #
tar xf source/libffi-${LIBFFI_VER}.tar.gz
cd libffi-${LIBFFI_VER}/

./configure \
    --build=$CBUILD \
    --host=$CHOST \
    --prefix=${EXTERNAL_LIBDIR} \
    --disable-shared \
    --enable-static

make
make install

cd ../
rm -rf libffi-${LIBFFI_VER}/

# - - liblzma - - #
tar xf source/xz-${XZ_VER}.tar.xz
cd xz-${XZ_VER}/

./configure \
    --build=$CBUILD \
    --host=$CHOST \
    --prefix=${EXTERNAL_LIBDIR} \
    --disable-doc \
    --disable-lzma-links \
    --disable-lzmadec \
    --disable-lzmainfo \
    --disable-nls \
    --disable-scripts \
    --disable-shared \
    --disable-symbol-versions \
    --disable-xz \
    --disable-xzdec \
    --enable-static

make
make install

cd ../
rm -rf xz-${XZ_VER}/

# - - libncursesw - - #
tar xf source/ncurses-${NCURSES_VER}.tar.gz
cd ncurses-${NCURSES_VER}/

./configure \
    --build=$CBUILD \
    --host=$CHOST \
    --prefix=${EXTERNAL_LIBDIR} \
    --mandir=${EXTERNAL_LIBDIR}/share/man \
    --disable-rpath-hack \
    --enable-pc-files \
    --enable-widec \
    --with-pkg-config-libdir=${EXTERNAL_LIBDIR}/lib/pkgconfig \
    --without-ada \
    --without-cxx-binding \
    --without-debug \
    --without-shared \
    --without-tests

make
make install

cd ../
rm -rf ncurses-${NCURSES_VER}/

# - - libz - - #
tar xf source/zlib-${ZLIB_VER}.tar.gz
cd zlib-${ZLIB_VER}/

./configure \
    --prefix=${EXTERNAL_LIBDIR} \
    --libdir=${EXTERNAL_LIBDIR}/lib

make
make install

cd ../
rm -rf zlib-${ZLIB_VER}/

# - - libzstd - - #
tar xf source/zstd-${ZSTD_VER}.tar.gz
cd zstd-${ZSTD_VER}/

mkdir haha/
cd haha/

LIBRARY_PATH="${STAGE1_BUILDDIR}/lib:${LIBRARY_PATH}" \
meson setup -Dbuildtype=plain \
    --prefix=${EXTERNAL_LIBDIR} \
    --default-library=static \
    -Db_ndebug=true \
    -Dbacktrace=disabled \
    -Dbin_contrib=false \
    -Dbin_programs=false \
    -Dbin_tests=false \
    -Dlz4=disabled \
    -Dlzma=disabled \
    -Dmulti_thread=enabled \
    -Dzlib=disabled \
    ../build/meson

samu
samu install

cd ../../
rm -rf zstd-${ZSTD_VER}/

# - - stage 2 - - #
mkdir -pv "${STAGE2_BUILDDIR}"
cd "${STAGE2_BUILDDIR}"

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
    -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF \
    -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
\
    -DFFI_INCLUDE_DIR=${EXTERNAL_LIBDIR}/include \
    -DFFI_INCLUDE_DIRS=${EXTERNAL_LIBDIR}/include \
    -DFFI_LIBRARIES=${EXTERNAL_LIBDIR}/lib/libffi.a \
    -DFFI_LIBRARY_DIR=${EXTERNAL_LIBDIR}/lib \
    -DFFI_STATIC_LIBRARIES=${EXTERNAL_LIBDIR}/lib/libffi.a \
\
    -DLIBLZMA_INCLUDE_DIR=${EXTERNAL_LIBDIR}/include \
    -DLIBLZMA_LIBRARY_DIR=${EXTERNAL_LIBDIR}/lib \
    -DLIBLZMA_LIBRARY_RELEASE=${EXTERNAL_LIBDIR}/lib/liblzma.a \
\
    -DZLIB_INCLUDE_DIR=${EXTERNAL_LIBDIR}/include \
    -DZLIB_LIBRARY_DIR=${EXTERNAL_LIBDIR}/lib \
    -DZLIB_LIBRARY_RELEASE=${EXTERNAL_LIBDIR}/lib/libz.a \
\
    -DLLVM_USE_STATIC_ZSTD=ON \
    -Dzstd_INCLUDE_DIR=${EXTERNAL_LIBDIR}/include \
    -Dzstd_LIBRARY=${EXTERNAL_LIBDIR}/lib/libzstd.a \
    -Dzstd_STATIC_LIBRARY=${EXTERNAL_LIBDIR}/lib/libzstd.a \
\
    -DCURSES_CURSES_LIBRARY=${EXTERNAL_LIBDIR}/lib/libncursesw.a \
    -DCURSES_FORM_LIBRARY=${EXTERNAL_LIBDIR}/lib/libformw.a \
    -DCURSES_INCLUDE_PATH=${EXTERNAL_LIBDIR}/include \
    -DCURSES_NCURSES_LIBRARY=${EXTERNAL_LIBDIR}/lib/libncursesw.a \
\
    ../llvm

time samu
samu install

# - - strip + debloat - - #
find "${RELEASE_DIR}" -type f \
    \( -name \*.a -a \
        ! -name libc++.a \
        ! -name libc++experimental.a \
        ! -name libclang_rt\* \
        ! -name libomp.a \
        ! -name libunwind.a \
    \) \
        -exec rm -rfv {} ';'

rm -rfv "${RELEASE_DIR}"/share

find "${RELEASE_DIR}"/bin -type f -exec strip --strip-all {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.a -exec strip --strip-debug {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.a -exec "${RANLIB}" {} ';'
find "${RELEASE_DIR}"/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'

# - - create compat symlinks - - #
CLANG_VER="$(echo $LLVM_VER | cut -c1-2)"

mkdir "${RELEASE_DIR}"/compat
pushd "${RELEASE_DIR}"/compat

ln -sfv ../bin/clang-${CLANG_VER} as
ln -sfv ../bin/clang-${CLANG_VER} c++
ln -sfv ../bin/clang-${CLANG_VER} cc
ln -sfv ../bin/clang-${CLANG_VER} cpp
ln -sfv ../bin/clang-${CLANG_VER} g++
ln -sfv ../bin/clang-${CLANG_VER} gcc
ln -sfv ../bin/lld                ld
ln -sfv ../bin/llvm-ar            ar
ln -sfv ../bin/llvm-ar            ranlib
ln -sfv ../bin/llvm-cov           gcov
ln -sfv ../bin/llvm-cxxfilt       c++filt
ln -sfv ../bin/llvm-nm            nm
ln -sfv ../bin/llvm-objcopy       objcopy
ln -sfv ../bin/llvm-objcopy       strip
ln -sfv ../bin/llvm-objdump       objdump
ln -sfv ../bin/llvm-readobj       readelf
ln -sfv ../bin/llvm-size          size
ln -sfv ../bin/llvm-strings       strings
ln -sfv ../bin/llvm-symbolizer    addr2line

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
