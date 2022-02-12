#!/bin/bash

## Generate emmylua annotations from ldoc project
## Usage: export.sh /path/to/folder/with/config.ld
## Output will be in annotations.lua file
## 
## Ldoc using next tags:
## @within - class inheritance
## @alias - rename type in emmylua output
## 
## Author: Maxim Tuprikov <insality@gmail.com>
## Github: https://github.com/Insality/emmylua-from-ldoc-annotations
## License: MIT
## Date: 10.2020


### Exit on Cmd+C / Ctrl+C
trap "exit" INT
trap clean EXIT
set -e

dump_file="./_temporary_ldoc.dump"
output_file="./annotations.lua"
original_path=$(pwd)

clean() {
	# rm -f ${dump_file}
	cd $original_path
}

script_path="`dirname \"$0\"`"
cd $script_path

### Generate dump file
echo "Make ldoc dump from $1"
echo "return" > $dump_file
cwd=$(pwd)
cd $1
dump_result="$(ldoc . --filter pl.pretty.dump --all >> ${cwd}/$dump_file)"
cd $cwd

### Generate annotations
echo "Generate annotations from ldoc to $output_file"
lua ./main.lua $dump_file > $output_file

