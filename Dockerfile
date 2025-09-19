FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends --no-install-suggests \
        ca-certificates \
        git \
        build-essential && \
    apt-get clean && rm -rf /var/cache/apt/archives/* && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/vlang/v /opt/v && \
    cd /opt/v && \
    make && \
    /opt/v/v symlink && \
    v version

# See https://wiki.debian.org/CrossCompiling
RUN dpkg --add-architecture arm64 && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture s390x && \
    dpkg --add-architecture ppc64el && \
    dpkg --add-architecture riscv64 && \
    apt-get update && \
    apt-get install --assume-yes --no-install-recommends --no-install-suggests \
        crossbuild-essential-arm64 \
        crossbuild-essential-armhf \
        crossbuild-essential-s390x \
        crossbuild-essential-ppc64el \
        crossbuild-essential-riscv64 \
        gcc-mingw-w64-x86-64 \
        clang lld && \
    apt-get clean && rm -rf /var/cache/apt/archives/* && rm -rf /var/lib/apt/lists/*

WORKDIR /app

USER 1000:1000

ENV VMODULES=/tmp/.vmodules
