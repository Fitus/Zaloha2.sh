#!/bin/bash

set -e

echo "PREPARING TEST DIRECTORIES 'test_source' AND 'test_backup'"

# prepare source directory with some test files
mkdir "test_source"
touch -t 201801010101 "test_source/samefile1"
touch -t 201801010101 "test_source/samefile2"
touch -t 201801010101 "test_source/samefile3"
touch -t 201901010101 "test_source/newfile"
touch -t 201901010101 "test_source/newerfile"

# prepare backup directory with some test files
mkdir "test_backup"
touch -t 201801010101 "test_backup/samefile1"
touch -t 201801010101 "test_backup/samefile2"
touch -t 201801010101 "test_backup/samefile3"
touch -t 201801010101 "test_backup/newerfile"
touch -t 201801010101 "test_backup/obsoletefile"

# prepare Zaloha metadata directory (999 file to simulate that Zaloha2 has already run, to avoid warning message)
mkdir "test_backup/.Zaloha_metadata"
touch -t 201807010101 "test_backup/.Zaloha_metadata/999_mark_executed"
