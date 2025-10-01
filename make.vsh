#!/usr/bin/env -S v run

import build
import crypto.sha256
import maps
import os
import term
import v.vmod

const program_name = os.getenv_opt('BUILD_PROG_NAME') or { vmod_name() }
const program_version = os.getenv_opt('BUILD_PROG_VERSION') or { vmod_version() }
const program_entrypoint = os.getenv_opt('BUILD_PROG_ENTRYPOINT') or { '.' }
const output_dir = os.abs_path(os.norm_path(os.getenv_opt('BUILD_OUTPUT_DIR') or { 'release' }))
const skip_targets = os.getenv('BUILD_SKIP_TARGETS')
const common_vflags = os.getenv_opt('BUILD_COMMON_VFLAGS') or { '-prod' }
const common_cflags = os.getenv_opt('BUILD_COMMON_CFLAGS') or { '-static' }
const debug = os.getenv('DEBUG')
const vexe = @VEXE

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

	file_ext string
		Extension for produced binary file. Useful for Windows builds. file_ext
		is concatenated to filename. For example for target named 'windows-amd64'
		and '.exe' file_ext you will get 'progname-1.2.3-windows-amd64.exe'.

	disabled bool
		If true target will be disabled. Target building will be skipped. Also
		target will not provided in tasks list in `./make.vsh -tasks` output.

	common_vflags bool
		If true, set additional flags listed in BUILD_COMMON_VFLAGS.
		See `./make.vsh -help` for info or read help_text const below. Is true
		by default.

	common_cflags bool
		The same as common_vflags, but for C compiler. Environment variable is
		BUILD_COMMON_CFLAGS. Is true by default.

	calculate_sha256 bool
		If true, calculate SHA256 hashsum of produced binary and create new
		artifact with the same name but with '.sha256' extension. File content
		is the same as Linux `sha256sum` utility output. Is true by default.

	See also Target sttruct definition in bottom of this file.

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
		cc:       'x86_64-w64-mingw32-gcc'
		vflags:   ['-os', 'windows']
		file_ext: '.exe'
	},
	Target{
		// FreeBSD build for now is dynamically linked even if -cflags -static is passed.
		// Also V forces the use of clang here (unless VCROSS_COMPILER_NAME envvar is set),
		// so -cc value doesn't matter.
		name:   'freebsd-amd64'
		cc:     'clang'
		vflags: ['-os', 'freebsd']
	},
]

const help_text = "
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
    ".trim_indent()

fn main() {
	if 'help' in os.args || '-help' in os.args || '--help' in os.args {
		println(help_text)
		exit(0)
	}
	mut context := build.context(default: 'all')
	mut targets := []string{}
	for build_target in build_targets {
		targets << build_target.name
		context.task(
			name:       build_target.name
			help:       'Make release build for ${build_target.name} target'
			run:        fn [build_target] (t build.Task) ! {
				make_build(build_target)!
			}
			should_run: fn [build_target] (t build.Task) !bool {
				return is_command_present(build_target.cc)!
					&& build_target.name !in skip_targets.split(',')
			}
		)
	}
	context.task(
		name:    'all'
		help:    'Make release builds for all target systems'
		depends: targets
		run:     |self| true
	)
	context.task(
		name: 'clean'
		help: 'Cleanup the output dir (${output_dir})'
		run:  |self| cleanup()!
	)
	context.run()
}

fn make_build(build_target Target) ! {
	printdbg('Env BUILD_PROG_NAME = ${program_name}')
	printdbg('Env BUILD_PROG_VERSION = ${program_version}')
	printdbg('Env BUILD_PROG_ENTRYPOINT = ${program_entrypoint}')
	printdbg('Env BUILD_OUTPUT_DIR = ${output_dir}')
	printdbg('Env BUILD_SKIP_TARGETS = ${skip_targets.split(',')}')
	printdbg('Env BUILD_COMMON_VFLAGS = ${common_vflags}')
	printdbg('Env BUILD_COMMON_CFLAGS = ${common_cflags}')

	os.mkdir(output_dir) or {}

	artifact := os.join_path_single(output_dir, program_name + '-' + program_version + '-' +
		build_target.name + build_target.file_ext)
	printdbg('Building artifact: ${artifact}')

	mut vargs := []string{}
	if build_target.common_vflags {
		for vflag in common_vflags.split(',') {
			if vflag != '' {
				vargs << vflag
			}
		}
	}
	for vflag in build_target.vflags {
		vargs << vflag
	}
	vargs << ['-cc', build_target.cc]
	if build_target.common_cflags {
		for cflag in common_cflags.split(',') {
			if cflag != '' {
				vargs << ['-cflags', cflag]
			}
		}
	}
	for cflag in build_target.cflags {
		vargs << ['-cflags', cflag]
	}
	for ldflag in build_target.ldflags {
		vargs << ['-ldflags', ldflag]
	}
	vargs << ['-o', artifact]
	vargs << program_entrypoint

	execute_command(vexe, vargs, env: build_target.env)!

	if build_target.calculate_sha256 {
		sha256sum_file := artifact + '.sha256'
		printdbg('Generating SHA256 sum: ${sha256sum_file}')
		file_bytes := os.read_bytes(artifact)!
		sum := sha256.sum(file_bytes)
		result := '${sum.hex()}  ${os.file_name(artifact)}\n'
		printdbg('Calculated SHA256: ${result}')
		os.write_file(sha256sum_file, result)!
	}
}

fn cleanup() ! {
	printdbg('Try to delete ${output_dir} recursively...')
	os.rmdir_all(output_dir) or {
		if err.code() == 2 {
			printdbg('${output_dir} does not exists')
		} else {
			return err
		}
	}
	printdbg('Cleanup done')
}

// Helper functions

fn vmod_name() string {
	if manifest := vmod.decode(@VMOD_FILE) {
		return manifest.name
	}
	return 'NAMEPLACEHOLDER'
}

fn vmod_version() string {
	if manifest := vmod.decode(@VMOD_FILE) {
		return manifest.version
	}
	return 'VERSIONPLACEHOLDER'
}

fn is_command_present(cmd string) !bool {
	if os.exists_in_system_path(cmd) {
		return true
	}
	if os.is_executable(os.abs_path(os.norm_path(cmd))) {
		return true
	}
	printwarn('Command ${term.bold(cmd)} is not found')
	return false
}

@[params]
struct CommandOptions {
	env map[string]string
}

fn execute_command(executable string, args []string, opts CommandOptions) ! {
	path := os.find_abs_path_of_executable(executable) or { os.norm_path(executable) }
	printdbg("Run '${path}' with arguments: ${args}")
	mut proc := os.new_process(path)
	proc.set_args(args)
	proc.set_environment(maps.merge(os.environ(), opts.env))
	proc.set_work_folder(os.getwd())
	proc.run()
	proc.wait()
	if proc.status == .exited && proc.code != 0 {
		return error('Command ${term.bold(path)} exited with non-zero code ${proc.code}')
	}
}

fn printdbg(s string) {
	if debug !in ['', '0', 'false', 'no'] {
		eprintln(term.dim(s))
	}
}

fn printwarn(s string) {
	eprintln(term.bright_yellow(s))
}

struct Target {
	name     string
	cc       string
	vflags   []string
	cflags   []string
	ldflags  []string
	file_ext string
	env      map[string]string

	common_vflags    bool = true
	common_cflags    bool = true
	calculate_sha256 bool = true
}
