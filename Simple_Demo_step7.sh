#!/bin/bash

echo "RUNNING ZALOHA2 AGAIN: SHOULD DO NOTHING, BECAUSE THE DIRECTORIES SHOULD BE SYNCHRONIZED AFTER THE RESTORE"

./Zaloha2.sh --sourceDir="test_source" --backupDir="test_backup"
#./Zaloha2.sh --sourceDir="test_source" --backupDir="test_backup" --color
