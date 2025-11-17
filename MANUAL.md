# Manual cross-compilation

This repository contains ready-made scripts that allow you to describe the
desired results and obtain them simply by running `./make.vsh`. However, to
better understand the process, it's worth considering the manual build.
This file describes the algorithm of actions automated in the aforementioned
scripts.

## Prepare the environment

We want reproducible builds. We also don't want to clutter our computer with
things needed exclusively for cross-compilation. Besides manipulating certain
packages in the OS can inadvertently damage the system.

Docker will help us achieve all our goals.
[Install it](https://docs.docker.com/get-started/get-docker/) if you haven't
already. Containers will ensure reproducible builds, as they will always run
in the same environment.

## Let's begin

Create a V programm. Just initialize empty V project in some dir:

```console
$ mkdir crossv
$ cd crossv
$ v init
Input your project description: Cross-compilation example
Input your project version: (0.0.0)
Input your project license: (MIT)
Initialising ...
Created binary (application) project `crossv`
```

Contents of `main.v`:

```v
module main

fn main() {
        println('Hello World!')
}
```

There is already an example Dockerfile in this repository, so here I will focus
on CLI. So let's run Debian Linux in container with current directory mounted:

```
docker run --rm -ti -v .:/app -w /app debian:trixie
```

See https://docs.docker.com/reference/cli/docker/container/run/ for details.

Now we will run shell commands inside container.

## Setup V compiler in container

Install prerequisistes:

```
apt update
apt install -y --no-install-recommends --no-install-suggests build-essential git ca-certificates file
```

Download and bootstrap V compiler:

```
export VMODULES=/tmp/vmodules VCACHE=/tmp/vcache
git clone --depth=1 https://github.com/vlang/v /opt/v && make -C /opt/v && /opt/v/v symlink
```

After this `v` command should work. Try:

```
v version
```

## Cross-compile to ARM64 (AArch64)

Your host is most likely an x86_64 computer. For the sake of example, let's
compile our Linux program for the AArch64 architecture.

First we need to add build requirements. Debian already have an excellent
[cross-compiling](//wiki.debian.org/CrossCompiling) support.

Prepate Debian package manager:

```
dpkg --add-architecture arm64
apt update
```

We need to install `crossbuild-essential-arm64` package:

```
apt install -y --no-install-recommends --no-install-suggests crossbuild-essential-arm64
```

Also there is packages for some other architectures which Debian supports:
https://packages.debian.org/search?keywords=crossbuild-essential&searchon=names&suite=stable&section=all

Now we have a GCC cross-compiler and some common libraries for ARM64.

To compile out project just run:

```
v -prod -cc aarch64-linux-gnu-gcc -o hello .
```

Let's make sure we've built the correct executable using the `file` utility:

```console
# file hello
hello: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, BuildID[sha1]=e9cfdee9abe5a80c304d489f243fbc60a22d93de, for GNU/Linux 3.7.0, not stripped
```

Binary is dynamically linked. To produce statically linked binary add `-cflags -static` flag:

```
v -prod -cc aarch64-linux-gnu-gcc -cflags -static -o hello .
```

Done.

Since we were operating as the root user inside the container, it's worth
changing the file owner:

```
chown 1000:1000 hello
```

Replace `1000:1000` with your actual `UID:GID` pair on host system.

Now we can exit from container:

```
exit
```
