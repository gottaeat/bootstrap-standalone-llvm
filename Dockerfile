FROM debian:latest as bootstrap-llvm

# although we build the code only for 64 bit x86, g{cc,++}-multilib is necessary
# for certain headers that libc++ requires to be present, weird.
RUN \
    apt update && \
    apt install -y \
        build-essential \
        cmake \
        curl \
        g++-multilib \
        gcc-multilib \
        git \
        libffi-dev \
        liblzma-dev \
        libncurses-dev \
        libz-dev \
        libzstd-dev \
        meson \
        python3 \
        zstd

# samurai is faster than ninja-build
RUN \
    git clone --depth=1 --recursive \
        https://github.com/michaelforney/samurai && \
    cd samurai && \
    make PREFIX=/usr install && \
    ln -sfv /usr/bin/samu /usr/bin/ninja && \
    cd ../ && \
    rm -rf samurai/

COPY ./ /repo

WORKDIR /repo
