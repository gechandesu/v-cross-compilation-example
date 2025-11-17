# V Cross-compilation Example

This example shows how to build statically linked binaries for different OS
and platforms for [V](https://vlang.io) programs.

The build is performed by the make.vsh script in V. I think it could be
simplified further, but the current version LGTM. Please read the comments
inside make.vsh for details.

The build is done inside a docker container with Debian 13 Trixie. Host is
`x86_64` Linux.

Produced binaries:

* Linux: `amd64`, `arm64`, `arm32` (`armhf`), `ppc64le`, `s390x`, `riscv64`
* Windows: `amd64`
* ~~FreeBSD: `amd64`~~ (disabled for now)

The example programm is just `Hello World!`. For complex programs you may need
to add more dependencies in build container.

I relied on Debian's excellent cross-compilation support (see the Dockerfile),
but with some elbow grease, you can compile the program for other architectures
and operating systems.

**Build**

Run:

```
./make.vsh
```

make.vsh script will build the Docker image and run crosscompile.vsh inside
a container.

The container image is large (almost 3GiB) due to the number of libraries
required for cross-compilation. The size could actually be reduced, but that's
what Debian provides by default in the `crossbuild-essential-*` packages. For
the same reason, building the image isn't very fast (up to ~3 minutes for me).

You may need change `docker_command` in `make.vsh` to `sudo docker` if your
host user does not have access to Docker daemon.

Look inside `release/` dir after compilation (:

## See Also

* [MANUAL.md](MANUAL.md) in this repository.
* `v help build`
* `v help build-c`
* https://docs.vlang.io/cross-compilation.html
* https://wiki.debian.org/CrossCompiling
* https://en.wikipedia.org/wiki/Cross_compiler#GCC_and_cross_compilation
* https://clang.llvm.org/docs/CrossCompilation.html
