#/bin/bash

### Exit on Cmd+C / Ctrl+C
trap "exit" INT
# trap clean EXIT
set -e

dump_file="./_temporary_ldoc.dump"
output_file="./annotations.lua"

# clean() {
    #rm -f ${dump_file}
# }


### Generate dump file
echo "Make ldoc from $1"
echo "return" > ./test.dump
cwd=$(pwd)
cd $1
echo "Current cwd $(pwd)"
dump_result="$(ldoc . --filter pl.pretty.dump >> ${cwd}/test.dump)"
cd $cwd

### Generate annotations
echo "Generate annotations from ldoc to annotations.lua"
lua main.lua ./test.dump > annotations.lua

