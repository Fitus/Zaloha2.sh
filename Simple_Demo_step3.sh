#!/bin/bash

metaDir='./test_backup/.Zaloha_metadata/'

echo "DISPLAYING STATISTICS ON THE RUN OF ZALOHA2"
echo
printf "Objects compared ..................................... %12s\n" $(                                                              awk 'END { print NR }' "${metaDir}"370_union_s_diff.csv )
printf "Unavoidable removals from <backupDir> ................ %12s\n" $(                                                              awk 'END { print NR }' "${metaDir}"510_exec1.csv        )
printf "Copies to <backupDir> ................................ %12s\n" $(                                                              awk 'END { print NR }' "${metaDir}"520_exec2.csv        )
printf "Reverse-copies to <sourceDir> ........................ %12s\n" $( [ ! -e "${metaDir}"530_exec3.csv ]        && echo '(off)' || awk 'END { print NR }' "${metaDir}"530_exec3.csv        )
printf "Remaining removals from <backupDir> .................. %12s\n" $( [ ! -e "${metaDir}"540_exec4.csv ]        && echo '(off)' || awk 'END { print NR }' "${metaDir}"540_exec4.csv        )
printf "Files compared byte by byte .......................... %12s\n" $( [ ! -e "${metaDir}"555_byte_by_byte.csv ] && echo '(off)' || awk 'END { print NR }' "${metaDir}"555_byte_by_byte.csv )
printf "From comparing of contents: copies to <backupDir> .... %12s\n" $( [ ! -e "${metaDir}"550_exec5.csv ]        && echo '(off)' || awk 'END { print NR }' "${metaDir}"550_exec5.csv        )
printf "Objects in synchronized state ........................ %12s\n" $(                                                              awk 'END { print NR }' "${metaDir}"505_target.csv       )
