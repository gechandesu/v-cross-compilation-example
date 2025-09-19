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
* FreeBSD: `amd64`

The example programm is just `Hello World!`. For complex programs you may need
to add more dependencies in build container.

I relied on Debian's excellent cross-compilation support (see the Dockerfile),
but with some elbow grease, you can compile the program for other architectures
and operating systems.

Build:

```
docker build . -t vlang-cross:latest-trixie
```

The container image is large (a little over 2GiB) due to the number of libraries
required for cross-compilation. The size could actually be reduced, but that's
what Debian provides by default in the `crossbuild-essential-*` packages. For
the same reason, building the image isn't very fast (up to ~3 minutes for me).

Start cross-compilation:

```
docker run --rm -v .:/app vlang-cross:latest-trixie env DEBUG=1 ./make.vsh
```

then look inside `release/` dir (:

## Synopsis

You can run the make.vsh script in two ways:

```
./make.vsh
# or
v run make.vsh
```

```
Build script options:
  -tasks    List available tasks.
  -help     Print this help message and exit. Aliases: help, --help.

Build can be configured throught environment variables:

  BUILD_PROG_NAME       Name of the compiled program. By default the name is
                        parsed from v.mod.
  BUILD_PROG_VERSION    Version of the compiled program. By default the name
                        is parsed from v.mod.
  BUILD_PROG_ENTRYPOINT The program entrypoint. Defaults to '.' (current dir).
  BUILD_OUTPUT_DIR      The directory where the build artifacts will be placed.
                        Defaults to './release'.
  BUILD_SKIP_TARGETS    List of build targets to skip. Expects comma-separated
                        list without whitespaces e.g. 'windows-amd64,linux-armhf'
  BUILD_COMMON_VFLAGS   The list of V flags is common for all targets. Expects
                        comma-separated list. Default is '-prod,-cross'.
  BUILD_COMMON_CFLAGS   Same as BUILD_COMMON_VFLAGS, but passed to underlying
                        C compiler. Default is '-static'.
  DEBUG                 If set enables the verbose output as dimmed text.
```

## See Also

* `v help build`
* `v help build-c`
* https://docs.vlang.io/cross-compilation.html
* https://wiki.debian.org/CrossCompiling
* https://en.wikipedia.org/wiki/Cross_compiler#GCC_and_cross_compilation
* https://clang.llvm.org/docs/CrossCompilation.html
