#!/bin/bash

echo "RUNNING ZALOHA2 AGAIN: SHOULD DO NOTHING, BECAUSE THE DIRECTORIES SHOULD BE ALREADY SYNCHRONIZED"

./Zaloha2.sh --sourceDir="test_source" --backupDir="test_backup"
#./Zaloha2.sh --sourceDir="test_source" --backupDir="test_backup" --color
