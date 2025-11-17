#!/usr/bin/env -S v run

import arrays.parallel
import os
import os.cmdline
import term
import v.vmod

/*
	SETTING BUILD TARGETS

	All build targets must be defined in the build_targets const below.
	Each target is a V struct. Fields are:

	name string
		The target name. Prefer to use https://wiki.osdev.org/Target_Triplet
		Note that target name will be used in output file name. For example
		the 'linux-riscv64' becomes to 'myprog-1.2.3-linux-riscv64'. This is
		very common naming scheme for compiled program distributions.

	cc string
		C Compiler to use e.g. '/usr/bin/gcc', 'clang', etc.

	vflags  []string
	cflags  []string
	ldflags []string
		Flags which will be passed to V compiler. See `v help build-c` for info.

	filename string
		Output file naming pattern. By default is '%n-%v-%t'.
			%n will be replaced with the program name (from v.mod by default)
			%v will be replaced with the program version (also from v.mod)
			%t will be replaced with the target name from `name` field.
		For example this is useful for Windows builds: for target named
		'windows-amd64' and '%n-%v-%t.exe' filename pattern value you will get
		artifact named 'progname-1.2.3-windows-amd64.exe'.

	See also Target struct definition below.

	V'S SPECIAL ENVIRONMENT VARIABLES

	    VCROSS_COMPILER_NAME    See vcross_compiler_name() in v.pref module.
	    VCROSS_LINKER_NAME      See vcross_linker_name() in v.pref module.
*/

const build_targets = [
	Target{
		name: 'linux-amd64'
		cc:   'gcc'
	},
	Target{
		name: 'linux-arm64'
		cc:   'aarch64-linux-gnu-gcc'
	},
	Target{
		name: 'linux-armhf'
		cc:   'arm-linux-gnueabihf-gcc'
	},
	Target{
		name: 'linux-ppc64le'
		cc:   'powerpc64le-linux-gnu-gcc'
	},
	Target{
		name: 'linux-s390x'
		cc:   's390x-linux-gnu-gcc'
	},
	Target{
		name: 'linux-riscv64'
		cc:   'riscv64-linux-gnu-gcc'
	},
	Target{
		name:     'windows-amd64'
		vflags:   ['-os', 'windows']
		filename: '%n-%v-%t.exe'
	},
	// FreeBSD build is buggy, disable it for now...
	// Target{
	// 	name:   'freebsd-amd64'
	// 	vflags: ['-os', 'freebsd']
	// },
]

struct Target {
	name     string
	cc       string
	vflags   []string
	cflags   []string
	ldflags  []string
	filename string = '%n-%v-%t'
}

fn (target Target) output_file() string {
	// vfmt off
	return target.filename.replace_each([
		'%n', build_config.program_name,
		'%v', build_config.program_version,
		'%t', target.name,
	])
	// vfmt on
}

const build_config = BuildConfig.new()

struct BuildConfig {
	program_name       string
	program_version    string
	program_entrypoint string
	output_dir         string
}

fn BuildConfig.new() BuildConfig {
	manifest := vmod.decode(@VMOD_FILE) or { vmod.Manifest{} }
	return BuildConfig{
		program_name:       os.getenv_opt('BUILD_PROG_NAME') or { manifest.name }
		program_version:    os.getenv_opt('BUILD_PROG_VERSION') or { manifest.version }
		program_entrypoint: os.getenv_opt('BUILD_PROG_ENTRYPOINT') or { '.' }
		output_dir:         os.abs_path(os.norm_path(os.getenv_opt('BUILD_OUTPUT_DIR') or {
			'release'
		}))
	}
}

fn make_build(build_target Target) ! {
	artifact := os.join_path_single(build_config.output_dir, build_target.output_file())

	eprintln(term.bold('Building artifact: ${artifact}'))

	os.mkdir_all(os.dir(artifact)) or {}

	mut vargs := []string{}
	if build_target.cc != '' {
		vargs << ['-cc', build_target.cc]
	}
	for vflag in build_target.vflags {
		vargs << vflag
	}
	for cflag in build_target.cflags {
		vargs << ['-cflags', cflag]
	}
	for ldflag in build_target.ldflags {
		vargs << ['-ldflags', ldflag]
	}
	vargs << ['-o', artifact]
	vargs << build_config.program_entrypoint

	execute_command(@VEXE, vargs)!
}

fn execute_command(executable string, args []string) ! {
	path := os.find_abs_path_of_executable(executable) or { os.norm_path(executable) }
	printdbg("Run '${path}' with arguments: ${args}")
	mut proc := os.new_process(path)
	proc.set_args(args)
	proc.set_work_folder(os.getwd())
	proc.run()
	proc.wait()
	if proc.status == .exited && proc.code != 0 {
		return error('Command ${term.bold(path)} exited with non-zero code ${proc.code}')
	}
}

fn printdbg(s string) {
	if os.getenv('DEBUG') !in ['', '0', 'false', 'no'] {
		eprintln(term.dim(s))
	}
}

@[noreturn]
fn errexit(s string) {
	eprintln(term.failed('Error: ${s}'))
	exit(1)
}

fn main() {
	args := os.args[1..]

	mut targets := map[string]Target{}
	for target in build_targets {
		targets[target.name] = target
	}

	options := cmdline.only_options(args)
	if args.contains('help') || options.contains('-help') || options.contains('--help') {
		println(help_text)
		exit(0)
	}
	if options.contains('-targets') {
		for name, _ in targets {
			println(name)
		}
		exit(0)
	}
	if options.contains('-release') {
		os.setenv('VFLAGS', '${os.getenv('VFLAGS')} -prod -cflags -static'.trim_space(),
			true)
	}

	printdbg('Args: ${args}')
	printdbg('VFLAGS=${os.getenv('VFLAGS')}')
	printdbg('VJOBS=${os.getenv('VJOBS')}')
	printdbg(build_config.str())

	mut to_build := []Target{}
	for arg in cmdline.only_non_options(args) {
		to_build << targets[arg] or { errexit("Invalid target: '${arg}', abotring...") }
	}
	if to_build.len == 0 {
		to_build = targets.values()
	}

	parallel.run(to_build, |build_target| make_build(build_target) or { errexit(err.msg()) })
}

const help_text = "
    Build script options:
      -targets  List available targets.
      -help     Print this help message and exit. Aliases: help, --help.
      -release  Pass '-prod -cflags -static' flags to V.

    Build can be configured throught environment variables:
      DEBUG                 If set enables the verbose output as dimmed text.
      BUILD_PROG_NAME       Name of the compiled program. By default the name is
                            parsed from v.mod.
      BUILD_PROG_VERSION    Version of the compiled program. By default version
                            is parsed from v.mod.
      BUILD_PROG_ENTRYPOINT The program entrypoint. Defaults to '.' (current dir).
                            Specify file or module which have fn main() defined.
      BUILD_OUTPUT_DIR      The directory where the build artifacts will be placed.
                            Defaults to './release'.

    V-specific environment variables:
      VFLAGS        Set arbitrary flags for all jobs.
      VJOBS         Number of parallel jobs. Set it to enchanse compile speed.
	".trim_indent()
