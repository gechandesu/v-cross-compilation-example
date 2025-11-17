#!/usr/bin/env -S v run

import build
import crypto.sha256
import os
import term

const output_dir = './release'
const docker_command = 'docker'
const docker_image = 'vlang-cross:latest-trixie'
const compile_command = 'env VFLAGS="-cflags -s" DEBUG=1 ./crosscompile.vsh -release'

const help_text = '
    Options:
      -tasks    List available tasks.
      -help     Print this help message and exit. Aliases: help, --help.
    '.trim_indent()

if 'help' in os.args || '-help' in os.args || '--help' in os.args {
	println(help_text)
	exit(0)
}

mut context := build.context(default: 'release')

context.task(
	name: docker_image
	help: 'Build Docker image for cross-compilation'
	run:  |self| os.system('${docker_command} build -t ${docker_image} .')
)

context.task(
	name:       'build'
	help:       'Build binaries'
	run:        |self| os.system('${docker_command} run --rm -v .:/app ${docker_image} ${compile_command}')
	should_run: |self| os.is_dir_empty(output_dir)
	depends:    [docker_image]
)

context.task(
	name:    'sha256sums'
	help:    'Calculate SHA256 sums for built binaries'
	run:     |self| os.walk(output_dir, fn (file string) {
		out_file := os.abs_path(file + '.sha256')
		eprintln(term.bold('Generating: ${out_file}'))
		data := os.read_bytes(file) or { return }
		sum := sha256.sum(data)
		result := '${sum.hex()}  ${os.file_name(file)}\n'
		os.write_file(out_file, result) or { return }
	})
	depends: ['build']
)

context.task(
	name:    'release'
	help:    'Make release'
	run:     |self| true
	depends: ['sha256sums']
)

context.task(
	name: 'clean'
	help: 'Cleanup build directory (delete all build artifacts)'
	run:  |self| os.rmdir_all(output_dir) or {}
)

context.run()
