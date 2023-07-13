#!/bin/bash

# Terminate on errors
set -e


printf "Synchronising submodules... "
git submodule sync --recursive >> /dev/null
git submodule update --recursive --remote --init >> /dev/null
printf "DONE\n\n"

cd protos

files=$(find jellyfish -name "*.proto")

printf "Compiling:\n"
count=1
total=${#files[@]}
for file in $files; do
  printf "Compile file %s %s ... " $count $file
  protoc --elixir_out=../lib/protos $file
  printf "DONE\n"
  count=$(($count + 1))
done

cd ..

mix format "lib/protos/**/*.ex"