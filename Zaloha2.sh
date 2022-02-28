#!/bin/bash

function zaloha_docu {
  less << 'ZALOHADOCU'
###########################################################

MIT License

Copyright (c) 2019 Fitus

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

###########################################################

OVERVIEW

Zaloha is a small and simple directory synchronizer:

 * Zaloha is a BASH script that uses only FIND, SORT and AWK. All you need
   is THIS file. For documentation, also read THIS file.
 * Cyber-secure: No new binary code, no new open ports, no interaction with
   the Internet, easily reviewable.
 * Three operation modes are available: Local Mode, Remote Source Mode and
   Remote Backup Mode
 * Local Mode: Both <sourceDir> and <backupDir> are available locally
   (local HDD/SSD, flash drive, mounted Samba or NFS volume).
 * Remote Source Mode: <sourceDir> is on a remote source host that can be
   reached via SSH/SCP, <backupDir> is available locally.
 * Remote Backup Mode: <sourceDir> is available locally, <backupDir> is on a
   remote backup host that can be reached via SSH/SCP.
 * Zaloha does not lock files while copying them. No writing on either directory
   may occur while Zaloha runs.
 * Zaloha always copies whole files via the operating system's CP command
   or the SCP command (= no delta-transfer like in RSYNC).
 * Zaloha is not limited by memory (metadata is processed as CSV files,
   no limits for huge directory trees).
 * Zaloha has optional reverse-synchronization features (details below).
 * Zaloha can optionally compare the contents of files (details below).
 * Zaloha prepares scripts for case of eventual restore (can be optionally
   switched off to shorten the analysis phase, details below).

To detect which files need synchronization, Zaloha compares file sizes and
modification times. It is clear that such detection is not 100% waterproof.
A waterproof solution requires comparing file contents, e.g. via "byte by byte"
comparison or via SHA-256 hashes. However, such comparing increases the
processing time by orders of magnitude. Therefore, it is not enabled by default.
Section Advanced Use of Zaloha describes two alternatives how to enable it.

Zaloha asks to confirm actions before they are executed, i.e. prepared actions
can be skipped, exceptional cases manually resolved, and Zaloha re-run.
For automatic operations, use the "--noExec" option to tell Zaloha to not ask
and to not execute the actions (but still prepare the scripts).

<sourceDir> and <backupDir> can be on different filesystem types if the
filesystem limitations are not hit. Such limitations are (e.g. in case of
ext4 -> FAT): not allowed characters in filenames, filename uppercase
conversions, file size limits, etc.

No writing on either directory may occur while Zaloha runs (no file locking is
implemented). In high-availability IT operations, a higher class of backup
solution should be deployed, based on taking filesystem snapshots at times when
writing processes are stopped for a short instant (i.e. functionality that must
be supported by the underlying OS). If either directory contains data files
of running databases, then they must be excluded from backups on file level.
Databases have their own logic of backups, replications and failovers, usually
based on transactional logs, and it is plainly wrong to intervene with generic
tools that operate on files and directories. Dedicated tools provided by the
database vendor shall be used.

Handling of "weird" characters in filenames was a special focus during
development of Zaloha (details below).

On Linux/Unics, Zaloha runs natively. On Windows, Cygwin is needed.

Repository: https://github.com/Fitus/Zaloha2.sh

An add-on script to create hardlink-based snapshots of the backup directory
exists, that allows to create "Time Machine"-like backup solutions:

Repository of add-on script: https://github.com/Fitus/Zaloha2_Snapshot.sh

###########################################################

MORE DETAILED DESCRIPTION

The operation of Zaloha can be partitioned into five steps, in that following
actions are performed:

Exec1:  unavoidable removals from <backupDir> (objects of conflicting types
        which occupy needed namespace)
-----------------------------------
RMDIR     regular remove directory from <backupDir>
REMOVE    regular remove file from <backupDir>
REMOVE.!  remove file from <backupDir> which is newer than the
          last run of Zaloha
REMOVE.l  remove symbolic link from <backupDir>
REMOVE.x  remove other object from <backupDir>, x = object type (p/s/c/b/D)

Exec2:  copy files/directories to <backupDir> which exist only in <sourceDir>,
        or files which are newer in <sourceDir>
-----------------------------------
MKDIR     regular create new directory in <backupDir>
NEW       regular create new file in <backupDir>
UPDATE    regular update file in <backupDir>
UPDATE.!  update file in <backupDir> which is newer than the last run of Zaloha
UPDATE.?  update file in <backupDir> by a file in <sourceDir> which is not newer
          (or not newer by 3600 secs if option "--ok3600s" is given plus
           an eventual 2 secs FAT tolerance)
unl.UP    unlink file in <backupDir> + UPDATE (can be switched off via the
          "--noUnlink" option, see below)
unl.UP.!  unlink file in <backupDir> + UPDATE.! (can be switched off via the
          "--noUnlink" option, see below)
unl.UP.?  unlink file in <backupDir> + UPDATE.? (can be switched off via the
          "--noUnlink" option, see below)
SLINK.n   create new symbolic link in <backupDir> (if synchronization of
          symbolic links is activated via the "--syncSLinks" option)
SLINK.u   update (= unlink+create) a symbolic link in <backupDir> (if
          synchronization of symbolic links is activated via the
          "--syncSLinks" option)
ATTR:ugmT update only attributes in <backupDir> (u=user ownership,
          g=group ownership, m=mode, T=modification time)
          (optional features, see below)

Exec3:  reverse-synchronization from <backupDir> to <sourceDir> (optional
        feature, can be activated via the "--revNew" and "--revUp" options)
-----------------------------------
REV.MKDI  reverse-create parent directory in <sourceDir> due to REV.NEW
REV.NEW   reverse-create file in <sourceDir> (if a standalone file in
          <backupDir> is newer than the last run of Zaloha)
REV.UP    reverse-update file in <sourceDir> (if the file in <backupDir>
          is newer than the file in <sourceDir>)
REV.UP.!  reverse-update file in <sourceDir> which is newer
          than the last run of Zaloha (or newer than the last run of Zaloha
          minus 3600 secs if option "--ok3600s" is given)

Exec4:  remaining removals of obsolete files/directories from <backupDir>
        (can be optionally switched off via the "--noRemove" option)
-----------------------------------
RMDIR     regular remove directory from <backupDir>
REMOVE    regular remove file from <backupDir>
REMOVE.!  remove file from <backupDir> which is newer than the
          last run of Zaloha
REMOVE.l  remove symbolic link from <backupDir>
REMOVE.x  remove other object from <backupDir>, x = object type (p/s/c/b/D)

Exec5:  updates resulting from optional comparing contents of files
        (optional feature, can be activated via the "--byteByByte" or
         "--sha256" options)
-----------------------------------
UPDATE.b  update file in <backupDir> because its contents is not identical
unl.UP.b  unlink file in <backupDir> + UPDATE.b (can be switched off via the
          "--noUnlink" option, see below)

(internal use, for completeness only)
-----------------------------------
OK        object without needed action in <sourceDir> (either files or
          directories already synchronized with <backupDir>, or other objects
          not to be synchronized to <backupDir>). These records are necessary
          for preparation of shellscripts for the case of restore.
OK.b      file proven identical byte by byte (in CSV metadata file 555)
KEEP      object to be kept only in <backupDir>
uRMDIR    unavoidable RMDIR which goes into Exec1 (in CSV files 380 and 390)
uREMOVE   unavoidable REMOVE which goes into Exec1 (in CSV files 380 and 390)

###########################################################

INDIVIDUAL STEPS IN FULL DETAIL

Exec1:
------
Unavoidable removals from <backupDir> (objects of conflicting types which occupy
needed namespace). This must be the first step, because objects of conflicting
types in <backupDir> would prevent synchronization (e.g. a file cannot overwrite
a directory).

Unavoidable removals are prepared regardless of the "--noRemove" option.

Exec2:
------
Files and directories which exist only in <sourceDir> are copied to <backupDir>
(action codes NEW and MKDIR).

Further, Zaloha "updates" files in <backupDir> (action code UPDATE) if files
exist under same paths in both <sourceDir> and <backupDir> and the comparisons
of file sizes and modification times result in needed synchronization of the
files. If the files in <backupDir> are multiply linked (hardlinked), Zaloha
removes (unlinks) them first (action code unl.UP), to prevent "updating"
multiply linked files, which could lead to follow-up effects. This unlinking
can be switched off via the "--noUnlink" option.

Optionally, Zaloha can also synchronize attributes (u=user ownerships,
g=group ownerships, m=modes (permission bits)). This functionality can be
activated by the options "--pUser", "--pGroup" and "--pMode". The selected
attributes are then preserved during each MKDIR, NEW, UPDATE and unl.UP
action. Additionally, if these attributes differ on files and directories
for which no action is prepared, special action codes ATTR:ugm are prepared to
synchronize (only) the differing attributes.

Synchronization of attributes is an optional feature, because:
(1) the filesystem of <backupDir> might not be capable of storing these
attributes, or (2) it may be wanted that all files and directories in
<backupDir> are owned by the user who runs Zaloha.

Regardless of whether attributes are synchronized or not, an eventual restore
of <sourceDir> from <backupDir> including these attributes is possible thanks
to the restore scripts which Zaloha prepares in its Metadata directory
(see below).

Zaloha contains an optional feature to detect multiply linked (hardlinked) files
in <sourceDir>. If this feature is switched on (via the "--detectHLinksS"
option), Zaloha internally flags the second, third, etc. links to same file as
"hardlinks", and synchronizes to <backupDir> only the first link (the "file").
The "hardlinks" are not synchronized to <backupDir>, but Zaloha prepares a
restore script for them (file 830). If this feature is switched off
(no "--detectHLinksS" option), then each link to a multiply linked file is
treated as a separate regular file.

The detection of hardlinks brings two risks: Zaloha might not detect that a file
is in fact a hardlink, or Zaloha might falsely detect a hardlink while the file
is in fact a unique file. The second risk is more severe, because the contents
of the unique file will not be synchronized to <backupDir> in such case.
For that reason, Zaloha contains additional checks against falsely detected
hardlinks (see code of AWKHLINKS). Generally, use this feature only after proper
testing on your filesystems. Be cautious as inode-related issues exist on some
filesystems and network-mounted filesystems.

Symbolic links in <sourceDir>: There are two dimensions: The first dimension is
whether to follow them or not (the "--followSLinksS" option). If follow, then
the referenced files and directories are synchronized to <backupDir> and only
the broken symbolic links stay as symbolic links. If not follow, then all
symbolic links stay as symbolic links. See section Following Symbolic Links for
details. Now comes the second dimension: What to do with the symbolic links that
stay as symbolic links: They are always kept in the metadata and Zaloha prepares
a restore script for them (file 820). Additionally, if the option "--syncSLinks"
is given, Zaloha will indeed synchronize them to <backupDir> (action codes
SLINK.n or SLINK.u).

Zaloha does not synchronize other types of objects in <sourceDir> (named pipes,
sockets, special devices, etc). These objects are considered to be part of the
operating system or parts of applications, and dedicated scripts for their
(re-)creation should exist.

It was a conscious decision for a default behaviour to synchronize to
<backupDir> only files and directories and keep other objects in metadata only.
This gives more freedom in the choice of filesystem type for <backupDir>,
because every filesystem type is able to store files and directories,
but not necessarily the other objects.

Exec3:
------
This step is optional and can be activated via the "--revNew" and "--revUp"
options.

Why is this feature useful? Imagine you use a Windows notebook while working in
the field.  At home, you have got a Linux server to that you regularly
synchronize your data. However, sometimes you work directly on the Linux server.
That work should be "reverse-synchronized" from the Linux server (<backupDir>)
back to the Windows notebook (<sourceDir>) (of course, assumed that there is no
conflict between the work on the notebook and the work on the server).

REV.NEW: If standalone files in <backupDir> are newer than the last run of
Zaloha, and the "--revNew" option is given, then Zaloha reverse-copies that
files to <sourceDir> (action code REV.NEW). This might require creation of the
eventually missing but needed structure of parent directories (REV.MKDI).

REV.UP: If files exist under same paths in both <sourceDir> and <backupDir>,
and the files in <backupDir> are newer, and the "--revUp" option is given,
then Zaloha uses that files to reverse-update the older files in <sourceDir>
(action code REV.UP).

Optionally, to preserve attributes during the REV.MKDI, REV.NEW and REV.UP
actions: use options "--pRevUser", "--pRevGroup" and "--pRevMode".

If reverse-synchronization is not active: If no "--revNew" option is given,
then each standalone file in <backupDir> is considered obsolete (and removed,
unless the "--noRemove" option is given). If no "--revUp" option is given, then
files in <sourceDir> always update files in <backupDir> if their sizes and/or
modification times differ.

Please note that the reverse-synchronization is NOT a full bi-directional
synchronization where <sourceDir> and <backupDir> would be equivalent.
Especially, there is no REV.REMOVE action. It was a conscious decision to not
implement it, as any removals from <sourceDir> would introduce not acceptable
risks.

Reverse-synchronization to <sourceDir> increases the overall complexity of the
solution. Use it only in the interactive regime of Zaloha, where human oversight
and confirmation of the prepared actions are in place.
Do not use it in automatic operations.

Exec4:
------
Zaloha removes all remaining obsolete files and directories from <backupDir>.
This function can be switched off via the "--noRemove" option.

Why are removals from <backupDir> split into two steps (Exec1 and Exec4)?
The unavoidable removals must unconditionally occur first, also in Exec1 step.
But what about the remaining (avoidable) removals: Imagine a scenario when a
directory is renamed in <sourceDir>: If all removals were executed in Exec1,
then <backupDir> would transition through a state (namely between Exec1 and
Exec2) where the backup copy of the directory is already removed (under the old
name), but not yet created (under the new name). To minimize the chance for such
transient states to occur, the avoidable removals are postponed to Exec4.

Advise to this topic: In case of bigger reorganizations of <sourceDir>, also
e.g. in case when a directory with large contents is renamed, it is much better
to prepare a rename script (more generally speaking: a migration script) and
apply it to both <sourceDir> and <backupDir>, instead of letting Zaloha perform
massive copying followed by massive removing.

Exec5:
------
Zaloha updates files in <backupDir> for which the optional comparisons of their
contents revealed that they are in fact not identical (despite appearing
identical by looking at their file sizes and modification times).

The action codes are UPDATE.b and unl.UP.b (the latter is update with prior
unlinking of multiply linked target file, as described under Exec2).

Please note that these actions might indicate deeper problems like storage
corruption (or even a cyber security issue), and should be actually perceived
as surprises.

This step is optional and can be activated via the "--byteByByte" or "--sha256"
options.

Metadata directory of Zaloha
----------------------------
Zaloha creates a Metadata directory: <backupDir>/.Zaloha_metadata. Its location
can be changed via the "--metaDir" option.

The purposes of the individual files are described as comments in program code.
Briefly, they are:

 * AWK program files (produced from "here documents" in Zaloha)
 * Shellscripts to run FIND commands
 * CSV metadata files
 * Exec1/2/3/4/5 shellscripts
 * Shellscripts for the case of restore
 * Touchfile 999 marking execution of actions

Files persist in the Metadata directory until the next invocation of Zaloha.

To obtain information about what Zaloha did (counts of removed/copied files,
total counts, etc), do not parse the screen output: Query the CSV metadata files
instead. Query the CSV metadata files after AWKCLEANER. Do not query the raw
CSV outputs of the FIND commands (before AWKCLEANER) and the produced
shellscripts, because due to eventual newlines in filenames, they may contain
multiple lines per "record".

In some situations, the existence of the Zaloha metadata directory is unwanted
after Zaloha finishes. In such cases, put a command to remove it to the wrapper
script that invokes Zaloha. At the same time, use the option "--noLastRun" to
prevent Zaloha from running FIND on file 999 in the Zaloha metadata directory
to obtain the time of the last run of Zaloha.

Please note that by not keeping the Zaloha metadata directory, you sacrifice
some functionality (see "--noLastRun" option below), and you loose the CSV
metadata for an eventual analysis of problems and you loose the shellscripts
for the case of restore (especially the scripts to restore the symbolic links
and hardlinks (which are eventually kept in metadata only)).

Temporary Metadata directory of Zaloha
--------------------------------------
In the Remote Source Mode, Zaloha needs a temporary Metadata directory on the
remote source host for copying scripts to there, executing them and obtaining
the CSV file from the FIND scan of <sourceDir> from there.

In the Remote Backup Mode, Zaloha performs its main metadata processing in a
temporary Metadata directory on the local (= source) host and then copies only
select metadata files to the Metadata directory on the remote (= backup) host.

The default location of the temporary Metadata directory is
<sourceDir>/.Zaloha_metadata_temp and can be changed via the "--metaDirTemp"
option.

Shellscripts for case of restore
--------------------------------
Zaloha prepares shellscripts for the case of restore in its Metadata directory
(scripts 800 through 870). Each type of operation is contained in a separate
shellscript, to give maximum freedom (= for each script, decide whether to apply
or to not apply). Further, each shellscript has a header part where
key variables for whole script are defined (and can be adjusted as needed).

The production of the shellscripts for the case of restore may cause increased
processing time and/or storage space consumption. It can be switched off by the
"--noRestore" option.

In case of need, the shellscripts for the case of restore can also be prepared
manually by running the AWK program 700 on the CSV metadata file 505:

  awk -f "<AWK program 700>"                  \
      -v backupDir="<backupDir>"              \
      -v restoreDir="<restoreDir>"            \
      -v remoteBackup=<0 or 1>                \
      -v backupUserHost="<backupUserHost>"    \
      -v remoteRestore=<0 or 1>               \
      -v restoreUserHost="<restoreUserHost>"  \
      -v scpExecOpt="<scpExecOpt>"            \
      -v cpRestoreOpt="<cpRestoreOpt>"        \
      -v f800="<script 800 to be created>"    \
      -v f810="<script 810 to be created>"    \
      -v f820="<script 820 to be created>"    \
      -v f830="<script 830 to be created>"    \
      -v f840="<script 840 to be created>"    \
      -v f850="<script 850 to be created>"    \
      -v f860="<script 860 to be created>"    \
      -v f870="<script 870 to be created>"    \
      -v noR800Hdr=<0 or 1>                   \
      -v noR810Hdr=<0 or 1>                   \
      -v noR820Hdr=<0 or 1>                   \
      -v noR830Hdr=<0 or 1>                   \
      -v noR840Hdr=<0 or 1>                   \
      -v noR850Hdr=<0 or 1>                   \
      -v noR860Hdr=<0 or 1>                   \
      -v noR870Hdr=<0 or 1>                   \
      "<CSV metadata file 505>"

Note 1: All filenames/paths should begin with a "/" (if absolute) or with a "./"
(if relative), and <snapDir> and <restoreDir> must end with a terminating "/".

Note 2: If any of the filenames/paths passed into AWK as variables (<snapDir>,
<restoreDir> and the <scripts 8xx to be created>) contain backslashes as "weird
characters", replace them by ///b. The AWK program 700 will replace ///b back
to backslashes inside.

###########################################################

INVOCATION

Zaloha2.sh --sourceDir=<sourceDir> --backupDir=<backupDir> [ other options ... ]

--sourceDir=<sourceDir> is mandatory. <sourceDir> must exist, otherwise Zaloha
    throws an error (except when the "--noDirChecks" option is given).
    In Remote Source mode, this is the source directory on the remote source
    host. If <sourceDir> is relative, then it is relative to the SSH login
    directory of the user on the remote source host.

--backupDir=<backupDir> is mandatory. <backupDir> must exist, otherwise Zaloha
    throws an error (except when the "--noDirChecks" option is given).
    In Remote Backup mode, this is the backup directory on the remote backup
    host. If <backupDir> is relative, then it is relative to the SSH login
    directory of the user on the remote backup host.

--sourceUserHost=<sourceUserHost> indicates that <sourceDir> resides on a remote
    source host to be reached via SSH/SCP. Format: user@host

--backupUserHost=<backupUserHost> indicates that <backupDir> resides on a remote
    backup host to be reached via SSH/SCP. Format: user@host

--sshOptions=<sshOptions> are additional command-line options for the
    SSH commands, separated by spaces. Typical usage is explained in section
    Advanced Use of Zaloha - Remote Source and Remote Backup Modes.

--scpOptions=<scpOptions> are additional command-line options for the
    SCP commands, separated by spaces. Typical usage is explained in section
    Advanced Use of Zaloha - Remote Source and Remote Backup Modes.

--scpExecOpt=<scpExecOpt> can be used to override <scpOptions> specially for
    the SCP commands used during the execution phase.

--findSourceOps=<findSourceOps> are additional operands for the FIND command
    that scans <sourceDir>, to be used to exclude files or subdirectories in
    <sourceDir> from synchronization to <backupDir>. This is a complex topic,
    described in full detail in section FIND operands to control FIND commands
    invoked by Zaloha.

    The "--findSourceOps" option can be passed in several times. In such case
    the final <findSourceOps> will be the concatenation of the several
    individual <findSourceOps> passed in with the options.

--findGeneralOps=<findGeneralOps> are additional operands for the FIND commands
    that scan both <sourceDir> and <backupDir>, to be used to exclude "Trash"
    subdirectories, independently on where they exist, from Zaloha's scope.
    This is a complex topic, described in full detail in section FIND operands
    to control FIND commands invoked by Zaloha.

    The "--findGeneralOps" option can be passed in several times. In such case
    the final <findGeneralOps> will be the concatenation of the several
    individual <findGeneralOps> passed in with the options.

--findParallel  ... in the Remote Source and Remote Backup Modes, run the FIND
    scans of <sourceDir> and <backupDir> in parallel. As the FIND scans run on
    different hosts in the remote modes, this will save time.

--noExec        ... needed if Zaloha is invoked automatically: do not ask,
    do not execute the actions, but still prepare the scripts. The prepared
    scripts then will not contain shell tracing and the "set -e" instruction.
    This means that the scripts will ignore individual failed commands and try
    to do as much work as possible, which is a behavior different from the
    interactive regime, where scripts are traced and halt on the first error.

--noRemove      ... do not remove files, directories and symbolic links that
    are standalone in <backupDir>. This option is useful when <backupDir> should
    hold "current" plus "historical" data whereas <sourceDir> holds only
    "current" data.

    Please keep in mind that if objects of conflicting types in <backupDir>
    prevent synchronization (e.g. a file cannot overwrite a directory),
    removals are unavoidable and will be prepared regardless of this option.
    In such case Zaloha displays a warning message in the interactive regime.
    In automatic operations, the calling process should query the CSV metadata
    file 510 to detect this case.

--revNew        ... enable REV.NEW (= if standalone file in <backupDir> is
                    newer than the last run of Zaloha, reverse-copy it
                    to <sourceDir>)

--revUp         ... enable REV.UP (= if file in <backupDir> is newer than
                    file in <sourceDir>, reverse-update the file in <sourceDir>)

--detectHLinksS ... perform hardlink detection (inode-deduplication)
                    on <sourceDir>

--ok2s          ... tolerate +/- 2 seconds differences due to FAT rounding of
                    modification times to nearest 2 seconds (special case
                    [SCC_FAT_01] explained in Special Cases section below).
                    This option is necessary only if Zaloha is unable to
                    determine the FAT file system from the FIND output
                    (column 6).

--ok3600s       ... additional tolerable offset of modification time differences
                    of exactly +/- 3600 seconds (special case [SCC_FAT_01]
                    explained in Special Cases section below)

--byteByByte    ... compare "byte by byte" files that appear identical (more
                    precisely, files for which either "no action" (OK) or just
                    "update of attributes" (ATTR) has been prepared).
                    (Explained in the Advanced Use of Zaloha section below).
                    This comparison might dramatically slow down Zaloha.
                    If additional updates of files result from this comparison,
                    they will be executed in step Exec5. This option is
                    available only in the Local Mode.

--sha256        ... compare contents of files via SHA-256 hashes. There is an
                    almost 100% security that files are identical if they have
                    equal sizes and SHA-256 hashes. Calculation of the hashes
                    might dramatically slow down Zaloha. If additional updates
                    of files result from this comparison, they will be executed
                    in step Exec5. Moreover, if files have equal sizes and
                    SHA-256 hashes but different modification times, copying of
                    such files will be prevented and only the modification times
                    will be aligned (ATTR:T). This option is available in all
                    three modes (Local, Remote Source and Remote Backup).

--noUnlink      ... never unlink multiply linked files in <backupDir> before
                    writing to them

--extraTouch    ... use cp + touch -m instead of cp --preserve=timestamps
                    (special case [SCC_OTHER_01] explained in Special Cases
                    section below). This has also a subtle impact on access
                    times (atime): cp --preserve=timestamps obtains mtime and
                    atime from the source file (before it reads it and changes
                    its atime) and applies the obtained mtime and atime to the
                    target file. On the contrary, cp keeps atime of the target
                    file intact and touch -m just sets the correct mtime on the
                    target file.

--cpOptions=<cpOptions> can be used to override the default command-line options
                    for the CP commands used in the Local Mode (which are
                    "--preserve=timestamps" (or none if option "--extraTouch"
                    is given)).

                    This option can be used if the CP command needs a different
                    option(s) to preserve timestamps during copying, or e.g. to
                    instruct CP to preserve extended attributes during copying
                    as well, or the like:

                          --cpOptions='--preserve=timestamps,xattr'

--cpRestoreOpt=<cpRestoreOpt> can be used to override <cpOptions> specially for
                    the CP commands used in the restore scripts.

--pUser         ... preserve user ownerships, group ownerships and/or modes
--pGroup            (permission bits) during MKDIR, NEW, UPDATE and unl.UP
--pMode             actions. Additionally, if these attributes differ on files
                    and directories for which no action is prepared, synchronize
                    the differing attributes (action codes ATTR:ugm).
                    The options "--pUser" and "--pGroup" also apply to symbolic
                    links if their synchronization is active ("--syncSLinks").

--pRevUser      ... preserve user ownerships, group ownerships and/or modes
--pRevGroup         (permission bits) during REV.MKDI, REV.NEW and REV.UP
--pRevMode          actions

--followSLinksS ... follow symbolic links on <sourceDir>
--followSLinksB ... follow symbolic links on <backupDir>
                    Please see section Following Symbolic Links for details.

--syncSLinks    ... synchronize symbolic links from <sourceDir> to <backupDir>

--noWarnSLinks  ... suppress warnings related to symbolic links

--noRestore     ... do not prepare scripts for the case of restore (= saves
    processing time and disk space, see optimization note below). The scripts
    for the case of restore can still be produced ex-post by manually running
    the respective AWK program (700 file) on the source CSV file (505 file).

--optimCSV      ... optimize space occupied by CSV metadata files by removing
    intermediary CSV files after use (see optimization note below).
    If intermediary CSV metadata files are removed, an ex-post analysis of
    eventual problems may be impossible.

--metaDir=<metaDir> allows to place the Zaloha metadata directory to a different
    location than the default (which is <backupDir>/.Zaloha_metadata).
    The reasons for using this option might be:

      a) non-writable <backupDir> (if Zaloha is used to perform comparison only
        (i.e. with "--noExec" option))

      b) a requirement to have Zaloha metadata on a separate storage

      c) Zaloha is operated in the Local Mode, but <backupDir> is not available
         locally (which means that the technical integration options described
         under the section Advanced Use of Zaloha are utilized). In that case
         it is necessary to place the Metadata directory to a location
         accessible to Zaloha.

    If <metaDir> is placed to a different location inside of <backupDir>, or
    inside of <sourceDir> (in Local Mode), then it is necessary to explicitly
    pass a FIND expression to exclude the Metadata directory from the respective
    FIND scan via <findGeneralOps>.

    If Zaloha is used for multiple synchronizations, then each such instance
    of Zaloha must have its own separate Metadata directory.

    In Remote Backup Mode, if <metaDir> is relative, then it is relative to the
    SSH login directory of the user on the remote backup host.

--metaDirTemp=<metaDirTemp> may be used only in the Remote Source or Remote
    Backup Modes, where Zaloha needs a temporary Metadata directory too. This
    option allows to place it to a different location than the default
    (which is <sourceDir>/.Zaloha_metadata_temp).

    If <metaDirTemp> is placed to a different location inside of <sourceDir>,
    then it is necessary to explicitly pass a FIND expression to exclude it
    from the respective FIND scan via <findGeneralOps>.

    If Zaloha is used for multiple synchronizations in the Remote Source or
    Remote Backup Modes, then each such instance of Zaloha must have its own
    separate temporary Metadata directory.

    In Remote Source Mode, if <metaDirTemp> is relative, then it is relative to
    the SSH login directory of the user on the remote source host.

--noDirChecks   ... switch off the checks for existence of <sourceDir> and
    <backupDir>. (Explained in the Advanced Use of Zaloha section below).

--noLastRun     ... do not obtain time of the last run of Zaloha by running
                    FIND on file 999 in Zaloha metadata directory.
                    This makes Zaloha state-less, which might be a desired
                    property in certain situations, e.g. if you do not want to
                    keep the Zaloha metadata directory. However, this sacrifices
                    features based on the last run of Zaloha: REV.NEW and
                    distinction of actions on files newer than the last run
                    of Zaloha (e.g. distinction between UPDATE.! and UPDATE).

--noIdentCheck  ... do not check if objects on identical paths in <sourceDir>
                    and <backupDir> are identical (= identical inodes). This
                    check brings to attention cases where objects in <sourceDir>
                    and corresponding objects in <backupDir> are in reality
                    the same objects (possibly via hardlinks), which violates
                    the logic of backup. Switching off this check might be
                    necessary in some special uses of Zaloha.

--noFindSource  ... do not run FIND (script 210) to scan <sourceDir>
                    and use externally supplied CSV metadata file 310 instead
--noFindBackup  ... do not run FIND (script 220) to scan <backupDir>
                    and use externally supplied CSV metadata file 320 instead
   (Explained in the Advanced Use of Zaloha section below).

--no610Hdr      ... do not write header to the shellscript 610 for Exec1
--no621Hdr      ... do not write header to the shellscript 621 for Exec2
--no622Hdr      ... do not write header to the shellscript 622 for Exec2
--no623Hdr      ... do not write header to the shellscript 623 for Exec2
--no631Hdr      ... do not write header to the shellscript 631 for Exec3
--no632Hdr      ... do not write header to the shellscript 632 for Exec3
--no633Hdr      ... do not write header to the shellscript 633 for Exec3
--no640Hdr      ... do not write header to the shellscript 640 for Exec4
--no651Hdr      ... do not write header to the shellscript 651 for Exec5
--no652Hdr      ... do not write header to the shellscript 652 for Exec5
--no653Hdr      ... do not write header to the shellscript 653 for Exec5
   These options can be used only together with the "--noExec" option.
   (Explained in the Advanced Use of Zaloha section below).

--noR800Hdr     ... do not write header to the restore script 800
--noR810Hdr     ... do not write header to the restore script 810
--noR820Hdr     ... do not write header to the restore script 820
--noR830Hdr     ... do not write header to the restore script 830
--noR840Hdr     ... do not write header to the restore script 840
--noR850Hdr     ... do not write header to the restore script 850
--noR860Hdr     ... do not write header to the restore script 860
--noR870Hdr     ... do not write header to the restore script 870
   (Explained in the Advanced Use of Zaloha section below).

--noProgress    ... suppress progress messages during the analysis phase (less
                    screen output). If "--noProgress" is used together with
                    "--noExec", Zaloha does not produce any output on stdout
                    (traditional behavior of Unics tools).

--color         ... use color highlighting (can be used on terminals which
                    support ANSI escape codes)

--mawk          ... use mawk, the very fast AWK implementation based on a
                    bytecode interpreter. Without this option, awk is used,
                    which usually maps to GNU awk (but not always).
                    (Note: If you know that awk on your system maps to mawk,
                     use this option to make the mawk usage explicit, as this
                     option also turns off mawk's i/o buffering on places where
                     progress of commands is displayed, i.e. on places where
                     i/o buffering causes confusion and is unwanted).

--lTest         ... (do not use in real operations) support for lint-testing
                    of AWK programs

--help          ... show Zaloha documentation (using the LESS program) and exit

Optimization note: If Zaloha operates on directories with huge numbers of files,
especially small ones, then the size of metadata plus the size of scripts for
the case of restore may exceed the size of the files themselves. If this leads
to problems, use options "--noRestore" and "--optimCSV".

Zaloha must be run by a user with sufficient privileges to read <sourceDir> and
to write and perform other required actions on <backupDir>. In case of the REV
actions, privileges to write and perform other required actions on <sourceDir>
are required as well. Zaloha does not contain any internal checks as to whether
privileges are sufficient. Failures of commands run by Zaloha must be monitored
instead.

Zaloha does not contain protection against concurrent invocations with
conflicting <backupDir> (and for REV also conflicting <sourceDir>): this is
responsibility of the invoker, especially due to the fact that Zaloha may
conflict with other processes as well.

In case of failure: resolve the problem and re-run Zaloha with same parameters.
In the second run, Zaloha should not repeat the actions completed by the first
run: it should continue from the action on which the first run failed. If the
first run completed successfully, no actions should be performed in the second
run (this is an important test case, see below).

Typically, Zaloha is invoked from a wrapper script that does the necessary
directory mounts, then runs Zaloha with the required parameters, then directory
unmounts.

###########################################################

FIND OPERANDS TO CONTROL FIND COMMANDS INVOKED BY ZALOHA

Zaloha obtains information about the files and directories via the FIND command.

Ad FIND command itself: It must support the -printf operand, as this allows to
obtain all needed information from a directory in one scan (= one process),
which is efficient. GNU find supports the -printf operand, but some older
FIND implementations don't, so they cannot be used with Zaloha.

The FIND scans of <sourceDir> and <backupDir> can be controlled by two options:
Option "--findSourceOps" are additional operands for the FIND command that scans
<sourceDir> only, and the option "--findGeneralOps" are additional operands
for both FIND commands (scans of both <sourceDir> and <backupDir>).

Both options "--findSourceOps" and "--findGeneralOps" can be passed in several
times. This allows to construct the final <findSourceOps> and <findGeneralOps>
in Zaloha part-wise, e.g. expression by expression.

Difference between <findSourceOps> and <findGeneralOps>
-------------------------------------------------------
<findSourceOps> applies only to <sourceDir>. If files in <sourceDir> are
excluded by <findSourceOps> and files exist in <backupDir> under same paths,
then Zaloha evaluates the files in <backupDir> as obsolete (= removes them,
unless the "--noRemove" option is given, or eventually even attempts to
reverse-synchronize them (which leads to corner case [SCC_FIND_01]
(see the Corner Cases section))).

On the contrary, the files excluded by <findGeneralOps> are not visible to
Zaloha at all, neither in <sourceDir> nor in <backupDir>, so Zaloha will not
act on them.

The main use of <findSourceOps> is to exclude files or subdirectories in
<sourceDir> from synchronization to <backupDir>.

The main use of <findGeneralOps> is to exclude "Trash" subdirectories,
independently on where they exist, from Zaloha's scope.

Rules and limitations
---------------------
Both <findSourceOps> and <findGeneralOps> must consist of one or more
FIND expressions in the form of an OR-connected chain:

    expressionA -o expressionB -o ... expressionN -o

Adherence to this convention assures that Zaloha is able to correctly combine
<findSourceOps> with <findGeneralOps> and with own FIND expressions.

The OR-connected chain works so that if an earlier expression in the chain
evaluates TRUE, FIND does not evaluate following expressions, i.e. will not
evaluate the final -printf operand, so no output will be produced. In other
words, matching by any of the expressions leads to exclusion.

Further, the internal logic of Zaloha imposes the following limitations:

 * Exclusion of files by the "--findSourceOps" option: No limitations exist
   here, all expressions supported by FIND can be used (but make sure the
   exclusion applies only to files). Example: exclude all files smaller than
   1000 bytes:

    --findSourceOps='( -type f -a -size -1000c ) -o'

 * Exclusion of subdirectories by the "--findSourceOps" option: One limitation
   must be obeyed: If a subdirectory is excluded, all its contents must be
   excluded too. Why? If Zaloha sees the contents but not the subdirectory
   itself, it will prepare commands to create the contents of the subdirectory,
   but they will fail as the command to create the subdirectory itself (mkdir)
   will not be prepared. Example: exclude all subdirectories owned by user fred
   and all their contents:

    --findSourceOps='( -type d -a -user fred ) -prune -o'

   The -prune operand instructs FIND to not descend into directories matched
   by the preceding expression.

 * Exclusion of files by the "--findGeneralOps" option: As <findGeneralOps>
   applies to both <sourceDir> and <backupDir>, and the objects in both
   directories are "matched" by file's paths, only expressions with -path or
   -name operands make sense. Why? If objects exist under same paths in both
   directories, Zaloha should either see both of them or none of them.
   Both -path and -name expressions assure this, but not necessarily the
   expressions based on other operands like -size, -user and so on.
   Example: exclude core dumps (files named core) wherever they exist:

    --findGeneralOps='( -type f -a -name core ) -o'

   Note 1: GNU find supports the -ipath and -iname operands for case-insensitive
   matching of paths and names. They fulfill the above described "both or none"
   criterion as well and hence are allowed too. The same holds for the -regex
   and -iregex operands supported by GNU find, as they act on paths as well.

   Note 2: As <findGeneralOps> act on both <sourceDir> and <backupDir> and the
   paths differ in the start point directories, the placeholder ///d/ must be
   used in the involved path patterns. This is described further below.

 * Exclusion of subdirectories by the "--findGeneralOps" option: Both above
   described limitations must be obeyed: Only expressions with -path or -name
   operands are allowed, and if subdirectories are excluded, all their contents
   must be excluded too. Notes 1 and 2 from previous bullet hold too.
   Example: exclude subdirectories lost+found wherever they exist:

    --findGeneralOps='( -type d -a -name lost+found ) -prune -o'

   If you do not care if an object is a file or a directory, you can abbreviate:

    --findGeneralOps='-name unwanted_name -prune -o'
    --findGeneralOps='-path unwanted_path -prune -o'

*** CAUTION <findSourceOps> AND <findGeneralOps>: Zaloha does not validate if
the described rules and limitations are indeed obeyed. Wrong <findSourceOps>
and/or <findGeneralOps> can break Zaloha. On the other hand, an eventual
advanced use by knowledgeable users is not prevented. Some <findSourceOps>
and/or <findGeneralOps> errors might be detected in the directories hierarchy
check in AWKCHECKER.

Troubleshooting
---------------
If FIND operands do not work as expected, debug them using FIND alone.
Let's assume, that this does not work as expected:

    --findSourceOps='( -type f -a -name *.tmp ) -o'

The FIND command to debug this is:

    find <sourceDir> '(' -type f -a -name '*.tmp' ')' -o -printf 'path: %P\n'

Beware of interpretation by your shell
--------------------------------------
Your shell might interpret certain special characters contained on the command
line. Should these characters be passed to the called program (= Zaloha)
uninterpreted, they must be quoted or escaped.

The BASH shell does not interpret any characters in strings quoted by single
quotes. In strings quoted by double-quotes, the situation is more complex.

Please see the respective shell documentation for more details.

Parsing of FIND operands by Zaloha
----------------------------------
<findSourceOps> and <findGeneralOps> are passed into Zaloha as single strings.
Zaloha has to split these strings into individual operands (words) and pass them
to FIND, each operand as a separate command line argument. Zaloha has a special
parser (AWKPARSER) to do this.

The trivial case is when each (space-delimited) word is a separate FIND operand.
However, if a FIND operand contains spaces, it must be enclosed in double-quotes
(") to be treated as one operand. Moreover, if a FIND operand contains
double-quotes themselves, then it too must be enclosed in double-quotes (")
and the original double-quotes must be escaped by second double-quotes ("").

Examples (for BASH for both single-quoted and double-quoted strings):

  * exclude all objects named Windows Security
  * exclude all objects named My "Secret" Things

    --findSourceOps='-name "Windows Security" -prune -o'
    --findSourceOps='-name "My ""Secret"" Things" -prune -o'

    --findSourceOps="-name \"Windows Security\" -prune -o"
    --findSourceOps="-name \"My \"\"Secret\"\" Things\" -prune -o"

Interpretation of special characters by FIND itself
---------------------------------------------------
In the patterns of the -path and -name expressions, FIND itself interprets
following characters specially (see FIND documentation): *, ?, [, ], \.

If these characters are to be taken literally, they must be handed over to
FIND backslash-escaped.

Examples (for BASH for both single-quoted and double-quoted strings):

  * exclude all objects whose names begin with abcd (i.e. FIND pattern abcd*)
  * exclude all objects named exactly mnop* (literally including the asterisk)

    --findSourceOps='-name abcd* -prune -o'
    --findSourceOps='-name mnop\* -prune -o'

    --findSourceOps="-name abcd* -prune -o"
    --findSourceOps="-name mnop\\* -prune -o"

The placeholder ///d/ for the start point directories
-----------------------------------------------------
If expressions with the "-path" operand are used in <findSourceOps>, the
placeholder ///d/ should be used in place of <sourceDir>/ in their path
patterns.

If expressions with the "-path" operand are used in <findGeneralOps>, the
placeholder ///d/ must (not should) be used in place of <sourceDir>/ and
<backupDir>/ in their path patterns, unless, perhaps, the <sourceDir> and
<backupDir> parts of the paths are matched by a FIND wildcard.

Zaloha will replace ///d/ by the start point directory that is passed to FIND
in the given scan, with eventual FIND pattern special characters properly
escaped (which relieves you from doing the same by yourself).

Example: exclude <sourceDir>/.git

    --findSourceOps="-path ///d/.git -prune -o"

Internally defined default for <findGeneralOps>
-----------------------------------------------
<findGeneralOps> has an internally defined default, used to exclude:

    <sourceDir or backupDir>/$RECYCLE.BIN
      ... Windows Recycle Bin (assumed to exist directly under <sourceDir> or
          <backupDir>)

    <sourceDir or backupDir>/.Trash_<number>*
      ... Linux Trash (assumed to exist directly under <sourceDir> or
          <backupDir>)

    <sourceDir or backupDir>/lost+found
      ... Linux lost + found filesystem fragments (assumed to exist directly
          under <sourceDir> or <backupDir>)

To replace this internal default with own <findGeneralOps>:

    --findGeneralOps=<your replacement>

To switch off this internal default:

    --findGeneralOps=

To extend (= combine, not replace) the internal default by own extension (note
the plus (+) sign):

    --findGeneralOps=+<your extension>

If several "--findGeneralOps" options are passed in, the plus (+) sign mentioned
above should be passed in only with the first instance, not with the second,
third (and so on) instances.

Known traps and problems
------------------------
Beware of matching the start point directories <sourceDir> or <backupDir>
themselves by the expressions and patterns.

In some FIND versions, the name patterns starting with the asterisk (*)
wildcard do not match objects whose names start with a dot (.).

###########################################################

FOLLOWING SYMBOLIC LINKS

Technically, the "--followSLinksS" and/or "--followSLinksB" options in Zaloha
"just" pass the -L option to the FIND commands that scan <sourceDir> and/or
<backupDir>. However, it takes a fair amount of text to describe the impacts:

If FIND is invoked with the -L option, it returns information about the objects
the symbolic links point to rather than the symbolic links themselves (unless
the symbolic links are broken). Moreover, if the symbolic links point to
directories, the FIND scans continue in that directories as if they were
subdirectories (= symbolic links are followed).

In other words: If the directory structure of <sourceDir> is spanned by symbolic
links and symbolic links are followed due to the "--followSLinksS" option,
the FIND output will contain the whole structure spanned by the symbolic links,
BUT will not give any clue that FIND was going over the symbolic links.

The same sentence holds for <backupDir> and the "--followSLinksB" option.

Corollary 1: Independently on whether <sourceDir> is a plain directory structure
or spanned by symbolic links, Zaloha will create a plain directory structure
in <backupDir>. If the structure of <backupDir> should by spanned by symbolic
links too (not necessarily identically to <sourceDir>), then the symbolic links
and the referenced objects must be prepared in advance and the "--followSLinksB"
option must be given to follow symbolic links on <backupDir> (otherwise Zaloha
would remove the prepared symbolic links on <backupDir> and create real files
and directories in place of them).

Corollary 2: The restore scripts are not aware of the symbolic links that
spanned the original structure. They will restore a plain directory structure.
Again, if the structure of the restored directory should be spanned by symbolic
links, then the symbolic links and the referenced objects must be prepared
in advance. Please note that if the option "--followSLinksS" is given, the file
820_restore_sym_links.sh will contain only the broken symbolic links (as these
were the only symbolic links reported by FIND as symbolic links in that case).

The abovesaid is not much surprising given that symbolic links are frequently
used to place parts of directory structures to different storage media:
The different storage media must be mounted, directories on them must be
prepared and referenced by the symbolic links before any backup (or restore)
operations can begin.

Corner case synchronization of attributes (user ownerships, group ownerships,
modes (permission bits)) if symbolic links are followed: the attributes are
synchronized on the objects the symbolic links point to, not on the symbolic
links themselves.

Corner case removal actions: Eventual removal actions on places where the
structure is held together by the symbolic links are problematic. Zaloha will
prepare the REMOVE (rm -f) or RMDIR (rmdir) actions due to the objects having
been reported to it as files or directories. However, if the objects are in
reality symbolic links, "rm -f" removes the symbolic links themselves, not the
referenced objects, and "rmdir" fails with the "Not a directory" error.

Corner case loops: Loops can occur if symbolic links are in play. Zaloha can
only rely on the FIND command to handle them (= prevent running forever).
GNU find, for example, contains an internal mechanism to handle loops.

Corner case multiple visits: Although loops are prevented by GNU find, multiple
visits to objects are not. This happens when objects can be reached both via the
regular path hierarchy as well as via symbolic links that point to that objects
(or to their parent directories).

Technical note for the case when the start point directories themselves are
symbolic links: Zaloha passes all start point directories to FIND with trailing
slashes, which instructs FIND to follow them if they are symbolic links.

###########################################################

TESTING, DEPLOYMENT, INTEGRATION

First, test Zaloha on a small and noncritical set of your data. Although Zaloha
has been tested on several environments, it can happen that Zaloha malfunctions
on your environment due to different behavior of the operating system, BASH,
FIND, SORT, AWK and other utilities. Perform tests in the interactive regime
first. If Zaloha prepares wrong actions, abort it at the next prompt.

After first synchronization, an important test is to run second synchronization,
which should execute no actions, as the directories should be already
synchronized.

Test Zaloha under all scenarios which can occur on your environment. Test Zaloha
with filenames containing "weird" or national characters.

Verify that all your programs that write to <sourceDir> change modification
times of the files written, so that Zaloha does not miss changed files.

Simulate the loss of <sourceDir> and perform test of the recovery scenario using
the recovery scripts prepared by Zaloha.

Automatic operations
--------------------
Additional care must be taken when using Zaloha in automatic operations
("--noExec" option):

Exit status and standard error of Zaloha and of the scripts prepared by Zaloha
must be monitored by a monitoring system used within your IT landscape.
Nonzero exit status and writes to standard error must be brought to attention
and investigated. If Zaloha itself fails, the process must be aborted.
The scripts prepared under the "--noExec" option do not halt on the first error,
also their zero exit status does not imply that there were no failed
individual commands.

Implement sanity checks to avoid data disasters like synchronizing <sourceDir>
to <backupDir> in the moment when <sourceDir> is unmounted, which would lead
to loss of backup data. Evaluate counts of actions prepared by Zaloha (count
records in CSV metadata files in Zaloha metadata directory). Abort the process
if the action counts exceed sanity thresholds defined by you, e.g. when Zaloha
prepares an unexpectedly high number of removals.

The process which invokes Zaloha in automatic regime should function as follows
(pseudocode):

  run Zaloha2.sh --noExec
  in case of failure: abort process
  perform sanity checks on prepared actions
  if ( sanity checks OK ) then
    execute script 610
    execute scripts 621, 622, 623
    execute scripts 631, 632, 633
    execute script 640
    execute scripts 651, 652, 653
    monitor execution (writing to stderr)
    if ( execution successful ) then
      execute script 690 to touch file 999
    end if
  end if

###########################################################

SPECIAL AND CORNER CASES

Cases related to the use of FIND
--------------------------------
Ideally, the FIND scans return data about all objects in the directories.
However, the options "--findSourceOps" and "--findGeneralOps" may cause parts
of the reality to be hidden (masked) from Zaloha, leading to these cases:

[SCC_FIND_01]
Corner case "--revNew" with "--findSourceOps": If files exist under same paths
in both <sourceDir> and <backupDir>, and in <sourceDir> the files are masked by
<findSourceOps> and in <backupDir> the corresponding files are newer than the
last run of Zaloha, Zaloha prepares REV.NEW actions (that are wrong). This is
an error which Zaloha is unable to detect. Hence, the shellscripts for Exec3
contain REV_EXISTS checks that throw errors in such situations.

[SCC_FIND_02]
Corner case RMDIR with "--findGeneralOps": If objects exist under a given
subdirectory of <backupDir> and all of them are masked by <findGeneralOps>,
and Zaloha prepares a RMDIR on that subdirectory, then that RMDIR fails with
the "Directory not empty" error.

Cases related to the FAT filesystem
-----------------------------------
[SCC_FAT_01]
To detect which files need synchronization, Zaloha compares file sizes and
modification times. If the file sizes differ, synchronization is needed.
The modification times are more complex:

 * If one of the filesystems is FAT (i.e. FAT16, VFAT, FAT32), Zaloha tolerates
   differences of +/- 2 seconds. This is necessary because FAT rounds the
   modification times to nearest 2 seconds, while no such rounding occurs on
   other filesystems. (Note: Why is a +/- 1 second tolerance not sufficient:
   In some situations, a "ceiling" to nearest 2 seconds was observed instead of
   "rounding", making a +/- 2 seconds tolerance necessary).

 * If Zaloha is unable to determine the FAT file system from the FIND output
   (column 6), it is possible to enforce the +/- 2 seconds tolerance via the
   "--ok2s" option.

 * In some situations, offsets of exactly +/- 1 hour (+/- 3600 seconds)
   must be tolerated as well. Typically, this is necessary when one of the
   directories is on a filesystem type that stores modification times
   in local time instead of in universal time (e.g. FAT), and the OS is not
   able, for some reason, to correctly adjust for daylight saving time while
   converting the local time.

 * The additional tolerable offsets of +/- 3600 seconds can be activated via the
   "--ok3600s" option. They are assumed to exist between files in <sourceDir>
   and files in <backupDir>, but not between files in <backupDir> and the
   999 file in <metaDir> (from which the time of the last run of Zaloha is
   obtained). This last note is relevant especially if <metaDir> is located
   outside of <backupDir> (which is achievable via the "--metaDir" option).

[SCC_FAT_02]
Corner case REV.UP with "--ok3600s": The "--ok3600s" option makes it harder
to determine which file is newer (decision UPDATE vs REV.UP). The implemented
solution for that case is that for REV.UP, the <backupDir> file must be newer
by more than 3600 seconds (plus an eventual 2 secs FAT tolerance).

[SCC_FAT_03]
Corner case FAT uppercase conversions: Explained by following example:

The source directory is on a Linux ext4 filesystem and contains the files
FILE.TXT, FILE.txt, file.TXT and file.txt in one of the subdirectories.
The backup directory is on a FAT-formatted USB flash drive. The synchronization
executes without visible problems, but in the backup directory, only FILE.TXT
exists after the synchronization.

What happened is that the OS/filesystem re-directed all four copy actions
into FILE.TXT. Also, after three overwrites, the backup of only one of the
four source files exists. Zaloha detects this situation on next synchronization
and prepares new copy commands, but they again hit the same problem.

The only effective solution seems to be the renaming of the source files to
avoid this type of name conflict.

Last note: A similar phenomenon has been observed in the Cygwin environment
running on Windows/ntfs too.

Cases related to hardlinked files
---------------------------------
[SCC_HLINK_01]
Corner case "--detectHLinksS" with new link(s) to same file added or removed:
The assignment of what link will be kept as "file" (f) and what links will be
tagged as "hardlinks" (h) in CSV metadata after AWKHLINKS may change, leading
to NEW and REMOVE actions.

[SCC_HLINK_02]
Corner case REV.UP with "--detectHLinksS": Zaloha supports reverse-update of
only the first links in <sourceDir> (the ones that stay tagged as "files" (f)
in CSV metadata after AWKHLINKS). See also [SCC_CONFL_02].

[SCC_HLINK_03]
Corner case UPDATE or REV.UP with hardlinked files: Updating a multiply linked
(hardlinked) file means that the new contents will appear under all other links,
and that may lead to follow-up effects.

[SCC_HLINK_04]
Corner case update of attributes with hardlinked files: Updated attributes on a
multiply linked (hardlinked) file will (with exceptions on some filesystem
types) appear under all other links, and that may lead to follow-up effects.

[SCC_HLINK_05]
Corner case if same directory is passed in as <sourceDir> and <backupDir>:
Zaloha will issue a warning about identical objects. No actions will be prepared
due to both directories being identical, except when the directory contains
multiply-linked (hardlinked) files and the "--detectHLinksS" option is given.
In that case, Zaloha will prepare removals of the second, third, etc. links to
same files. This interesting side-effect (or new use case) is explained as
follows: Zaloha will perform hardlink detection on <sourceDir> and for the
detected hardlinks (h) it prepares removals of the corresponding files in
<backupDir>, which is the same directory. The hardlinks can be restored by
restore script 830_restore_hardlinks.sh.

Cases related to conflicting object type combinations
-----------------------------------------------------
[SCC_CONFL_01]
Corner case REV.NEW with namespace on <sourceDir> needed for REV.MKDI or REV.NEW
actions is occupied by objects of conflicting types: The files in <backupDir>
will not be reverse-copied to <sourceDir>, but removed. As these files must be
newer than the last run of Zaloha, the actions will be REMOVE.!.

[SCC_CONFL_02]
Corner case "--detectHLinksS" with objects in <backupDir> under same paths as
the seconds, third etc. hardlinks in <sourceDir> (the ones that will be tagged
as "hardlinks" (h) in CSV metadata after AWKHLINKS): The objects in <backupDir>
will be (unavoidably) removed to prevent misleading situations in that for a
hardlinked file in <sourceDir>, <backupDir> would contain a different object
(or eventually even a different file) under same path.

[SCC_CONFL_03]
Corner case objects in <backupDir> under same paths as symbolic links in
<sourceDir>: The objects in <backupDir> will be (unavoidably) removed to prevent
misleading situations in that for a symbolic link in <sourceDir> a different
type of object would exist in <backupDir> under same path.
If the objects in <backupDir> are symbolic links too, they will be either
synchronized (if the "--syncSLinks" option is given) or kept (and not changed).
Please see section Following Symbolic Links on when symbolic links are
reported as symbolic links by FIND.

[SCC_CONFL_04]
Corner case objects in <backupDir> under same paths as other objects (p/s/c/b/D)
in <sourceDir>: The objects in <backupDir> will be (unavoidably) removed except
when they are other objects (p/s/c/b/D) too, in which case they will be kept
(but not changed).

Other cases
-----------
[SCC_OTHER_01]
In some situations (e.g. Linux Samba + Linux Samba client),
cp --preserve=timestamps does not preserve modification timestamps (unless on
empty files). In that case, Zaloha should be instructed (via the "--extraTouch"
option) to use subsequent extra TOUCH commands instead, which is a more robust
solution. In the scripts for case of restore, extra TOUCH commands are used
unconditionally.

[SCC_OTHER_02]
Corner case if the Metadata directory is in its default location (= no option
"--metaDir" is given) and <sourceDir>/.Zaloha_metadata exists as well (which
may be the case in chained backups (= backups of backups)): It will be excluded.
If a backup of that directory is needed as well, it should be solved separately.
Hint: if the secondary backup starts one directory higher, then this exclusion
will not occur anymore.

Why be concerned about backups of the Metadata directory of the primary backup:
keep in mind that Zaloha synchronizes to <backupDir> only files and directories
and keeps other objects in metadata (and the restore scripts) only.

[SCC_OTHER_03]
It is possible (but not recommended) for <backupDir> to be a subdirectory of
<sourceDir> and vice versa. In such cases, FIND expressions to avoid recursive
copying must be passed in via <findGeneralOps>.

###########################################################

HOW ZALOHA WORKS INTERNALLY

Handling and checking of input parameters should be self-explanatory.

The actual program logic is embodied in AWK programs, which are contained in
Zaloha as "here documents".

The AWK program AWKPARSER parses the FIND operands assembled from
<findSourceOps> and <findGeneralOps> and constructs the FIND commands.
The outputs of running these FIND commands are tab-separated CSV metadata files
that contain all information needed for following steps. These CSV metadata
files, however, must first be processed by AWKCLEANER to handle (escape)
eventual tabs and newlines in filenames + perform other required preparations.

The cleaned CSV metadata files are then checked by AWKCHECKER for unexpected
deviations (in which case an error is thrown and the processing stops).

The next (optional) step is to detect hardlinks: the CSV metadata file from
<sourceDir> will be sorted by device numbers + inode numbers. This means that
multiply-linked files will be in adjacent records. The AWK program AWKHLINKS
evaluates this situation: The type of the first link will be kept as "file" (f),
the types of the other links will be changed to "hardlinks" (h).

Then comes the core function of Zaloha. The CSV metadata files from <sourceDir>
and <backupDir> will be united and sorted by file's paths and the Source/Backup
indicators. This means that objects existing in both directories will be in
adjacent records, with the <backupDir> record coming first. The AWK program
AWKDIFF evaluates this situation (as well as records from objects existing in
only one of the directories), and writes target state of synchronized
directories with actions to reach that target state.

The output of AWKDIFF is then sorted by file's paths in reverse order (so that
parent directories come after their children) and post-processed by AWKPOSTPROC.
AWKPOSTPROC modifies actions on parent directories of files to REV.NEW and
objects to KEEP only in <backupDir>.

The remaining code uses the produced data to perform actual work, and should be
self-explanatory.

An interactive JavaScript flowchart exists that explains the internal processing
within Zaloha in a graphical and intuitive manner.

  Interactive JavaScript flowchart: https://fitus.github.io/flowchart.html

Understanding AWKDIFF is the key to understanding of whole Zaloha. An important
hint to AWKDIFF is that there can be five types of filesystem objects in
<sourceDir> and four types of filesystem objects in <backupDir>. At any given
path, each type in <sourceDir> can meet each type in <backupDir>, plus each
type can be standalone in either <sourceDir> or <backupDir>. Mathematically,
this results in ( 5 x 4 ) + 5 + 4 = 29 cases to be handled by AWKDIFF:

                           backupDir:    d       f       l     other  (none)
  ---------------------------------------------------------------------------
  sourceDir:  directory          d  |    1       2       3       4      21
              file               f  |    5       6       7       8      22
              hardlink           h  |    9      10      11      12      23
              symbolic link      l  |   13      14      15      16      24
              other      p/s/c/b/D  |   17      18      19      20      25
              (none)                |   26      27      28      29
  ---------------------------------------------------------------------------

  Note 1: Hardlinks (h) cannot occur in <backupDir>, because the type "h" is not
  reported by FIND but determined by AWKHLINKS that can operate only on
  <sourceDir>.

  Note 2: Please see section Following Symbolic Links on when symbolic links
  are reported as symbolic links by FIND.

The AWKDIFF code is commented on key places to make orientation easier.
A good case to begin with is case 6 (file in <sourceDir>, file in <backupDir>),
as this is the most important (and complex) case.

If you are a database developer, you can think of the CSV metadata files as
tables, and Zaloha as a program that operates on these tables: It fills them
with data obtained from the filesystems (via FIND), then processes the data
(defined sequence of sorts, sequential processings, unions and selects), then
converts the data to shellscripts, and finally executes the shellscripts
to apply the required changes back to the filesystems.

Among the operations which Zaloha performs, there is no operation which would
require the CSV metadata to fit as a whole into memory. This means that the size
of memory does not constrain Zaloha on how big "tasks" it can handle.
The critical operations from this perspective are the sorts. However,
GNU sort, for instance, is able to intelligently switch to an external
sort-merge algorithm, if it determines that the data is "too big",
thus mitigating this concern.

Talking further in database developer's language: The data model of all CSV
metadata files is the same and is described in form of comments in AWKPARSER.
Files 310 and 320 do not qualify as tables, as their fields and records are
broken by eventual tabs and newlines in filenames. In files 330 through 370,
field 2 is the Source/Backup indicator. In files 380 through 555, field 2 is
the Action Code.

The natural primary key in files 330 through 360 is the file's path (column 14).
In files 370 through 505, the natural primary key is combined column 14 with
column 2. In files 510 through 555, the natural primary key is again
column 14 alone.

The combined primary key in file 505 is obvious e.g. in the case of other object
in <sourceDir> and other object in <backupDir>: File 505 then contains an
OK record for the former and a KEEP record for the latter, both with the
same file's path (column 14).

  Data model as HTML table: https://fitus.github.io/data_model.html

###########################################################

TECHNIQUES USED BY ZALOHA TO HANDLE WEIRD CHARACTERS IN FILENAMES

Handling of "weird" characters in filenames was a special focus during
development of Zaloha. Actually, it was an exercise of how far can be gone with
a shellscript alone, without reverting to a C program. Tested were:
!"#$%&'()*+,-.:;<=>?@[\]^`{|}~, spaces, tabs, newlines, alert (bell) and
a few national characters (beyond ASCII 127). Please note that some filesystem
types and operating systems do not permit some of these weird characters at all.

Zaloha internally uses tab-separated CSV files, also tabs and newlines are major
disruptors. The solution is based on the following idea: POSIX (the most
"liberal" standard under which Zaloha must function) says that filenames may
contain all characters except slash (/, the directory separator) and ASCII NUL.
Hence, except these two, no character can be used as an escape character
(if we do not want to introduce some re-coding). Further, ASCII NUL is not
suitable, as it is widely used as a string delimiter. Then, let's have a look
at the directory separator itself: It cannot occur inside of filenames.
It separates file and directory names in the paths. As filenames cannot have
zero length, no two slashes can appear in sequence. The only exception is the
naming convention for network-mounted directories, which may contain two
consecutive slashes at the beginning. But three consecutive slashes
(a triplet ///) are impossible. Hence, it is a waterproof escape sequence.
This opens the way to represent a tab as ///t and a newline as ///n.

For display of filenames on terminal (and only there), control characters (other
than tabs and newlines) are displayed as ///c, to avoid terminal disruption.
(Such control characters are still original in the CSV metadata files).

Further, /// is used as first field in the CSV metadata files, to allow easy
separation of record lines from continuation lines caused by newlines in
filenames (it is impossible that continuation lines have /// as the first field,
because filenames cannot contain the newline + /// sequence).

Finally, /// are used as terminator fields in the CSV metadata files, to be able
to determine where the filenames end in a situation when they contain tabs and
newlines (it is impossible that filenames produce a field containing /// alone,
because filenames cannot contain the tab + /// sequence).

With these preparations, see how the AWKCLEANER works: For columns 14 and 16,
process CSV fields and records until a field containing /// is found. In such
special processing mode (in AWK code: fpr has value 1), every switch to a new
CSV field is a tab in the path, and every switch to a new record is a newline
in the path. AWKCLEANER assembles the fragments contained in the CSV fields
with the tabs (escaped as ///t) and newlines (escaped as ///n) to build the
resulting escaped paths that contain neither real tabs nor real newlines.

Zaloha checks that no input parameters contain ///, to avoid breaking of the
internal escape logic from the outside. The only exception are <findSourceOps>
and <findGeneralOps>, which may contain the ///d/ placeholder.

Additionally, the internal escape logic might be broken by target paths of
symbolic links: Unfortunately, the OSes do not normalize target paths with
consecutive slashes while writing them to the filesystems, and FIND does not
normalize them either in the -printf %l output. Actually, there seem to be no
constraints on the target paths of symbolic links. Hence, the /// triplets can
occur there as well. This prohibits their safe processing within the above
described FIND-AWKCLEANER algorithm. Instead, a special solution is implemented
that involves running an auxiliary script (205_read_slink.sh) for each symbolic
link that contains three or more consecutive slashes (found by FIND expression
-lname *///*). This script obtains the target paths of such symbolic links and
escapes slashes by ///s, tabs by ///t and newlines by ///n. The escaped target
paths are then put into extra records in files 310 and 320, and AWKCLEANER
merges them into the regular records (column 16) in the cleaned files 330
and 340. Performance-wise, running the auxiliary script 205 per symbolic link
is not ideal, but the above described symbolic links should be rare occurrences.

An additional challenge is passing of variable values to AWK. During its
lexical parsing, AWK interprets backslash-led escape sequences. To avoid this,
backslashes are converted to ///b in the BASH script, and ///b are converted
back to backslashes in the AWK programs.

In the shellscripts produced by Zaloha, single quoting is used, hence single
quotes are disruptors. As a solution, the '"'"' quoting technique is used.

The SORT commands are invoked under the LC_ALL=C environment variable, to avoid
problems caused by some locales that ignore slashes and other punctuations
during sorting.

In the CSV metadata files 330 through 500 (i.e. those which undergo the sorts),
file's paths (field 14) have directory separators (/) appended and all
directory separators then converted to ///s. This is to ensure correct sort
ordering. Imagine the ordering bugs that would happen otherwise:
  Case 1: given dir and dir!, they would be sort ordered:
          dir, dir!, dir!/subdir, dir/subdir.
  Case 2: given dir and dir<tab>ectory, they would be sort ordered:
          dir/!subdir1, dir///tectory, dir/subdir2.

Zaloha does not contain any explicit handling of national characters in
filenames (= characters beyond ASCII 127). It is assumed that the commands used
by Zaloha handle them transparently (which should be tested on environments
where this topic is relevant). <sourceDir> and <backupDir> must use the same
code page for national characters in filenames, because Zaloha does not contain
any code page conversions.

###########################################################

ADVANCED USE OF ZALOHA - REMOTE SOURCE AND REMOTE BACKUP MODES

Remote Source Mode
------------------
In the Remote Source Mode, <sourceDir> is on a remote source host that can be
reached via SSH/SCP, and <backupDir> is available locally. This mode is
activated by the "--sourceUserHost" option.

The FIND scan of <sourceDir> is run on the remote side in an SSH session, the
FIND scan of <backupDir> runs locally. The subsequent sorts + AWK processing
steps occur locally. The Exec1/2/3/4/5 steps are then executed as follows:

Exec1: The shellscript 610 is executed locally.

Exec2: All three shellscripts 621, 622 and 623 are executed locally. The script
622 contains SCP commands instead of CP commands.

Exec3: The shellscript 631 contains pre-copy actions and is run on the remote
side "in one batch". The shellscript 632 contains the individual SCP commands
to be executed locally. The shellscript 633 contains post-copy actions and
is run on the remote side "in one batch".

Exec4 (shellscript 640): same as Exec1

Exec5 (shellscripts 651, 652 and 653): same as Exec2

Remote Backup Mode
------------------
In the Remote Backup Mode, <sourceDir> is available locally, and <backupDir> is
on a remote backup host that can be reached via SSH/SCP. This mode is activated
by the "--backupUserHost" option.

The FIND scan of <sourceDir> runs locally, the FIND scan of <backupDir> is run
on the remote side in an SSH session. The subsequent sorts + AWK processing
steps occur locally. The Exec1/2/3/4/5 steps are then executed as follows:

Exec1: The shellscript 610 is run on the remote side "in one batch", because it
contains only RMDIR and REMOVE actions to be executed on <backupDir>.

Exec2: The shellscript 621 contains pre-copy actions and is run on the remote
side "in one batch". The shellscript 622 contains the individual SCP commands
to be executed locally. The shellscript 623 contains post-copy actions and
is run on the remote side "in one batch".

Exec3: All three shellscripts 631, 632 and 633 are executed locally. The script
632 contains SCP commands instead of CP commands.

Exec4 (shellscript 640): same as Exec1

Exec5 (shellscripts 651, 652 and 653): same as Exec2

Note
----
Running multiple actions on the remote side via SSH "in one batch" has
positive performance effects on networks with high latency, compared with
running individual commands via SSH individually (which would require a network
round-trip for each individual command).

SSH connection
--------------
For all SSH/SCP-related setups, read the SSH/SCP documentation first.

It is recommended to use SSH connection multiplexing, where a master connection
is established before invoking Zaloha. The subsequent SSH and SCP commands
invoked by Zaloha then connect to it, thus avoiding repeated overheads of
establishing new connections. This also removes the need for repeated entering
of passwords, which is necessary if no other authentication method is used,
e.g. the SSH Public Key authentication.

The SSH master connection is typically created as follows:

  ssh -nNf -o ControlMaster=yes                   \
           -o ControlPath='~/.ssh/cm-%r@%h:%p'    \
           <remoteUserHost>

To instruct the SSH and SCP commands invoked by Zaloha to use the SSH master
connection, use the options "--sshOptions" and "--scpOptions":

  --sshOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'
  --scpOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'

After use, the SSH master connection should be terminated as follows:

  ssh -O exit -o ControlPath='~/.ssh/cm-%r@%h:%p' <remoteUserHost>

SCP Progress Meter
------------------
SCP contains a Progress Meter that is useful when copying large files.
It continuously displays the percent of transfer done, the amount transferred,
the bandwidth usage and the estimated time of arrival.

In Zaloha, the SCP Progress Meters appear both in the analysis phase
(copying of metadata files to/from the remote side) as well as in the
execution phase (executions of the scripts 622, 632 and 652).

In the analysis phase, the display of the SCP Progress Meters (along with all
other analysis messages) can be switched off by the "--noProgress" option.
Internally, this translates to the "-q" option for the respective SCP commands.

In the execution phase, the display of the SCP Progress Meters can be switched
off via the option "--scpExecOpt" (= override <scpOptions> by SCP options with
"-q" added).

Technical note: SCP never displays its Progress Meter if it detects that its
standard output is not connected to a terminal. To support the SCP Progress
Meters in the execution phase, Zaloha does an I/O redirection which pipes the
shell traces through the AWK filter 102 but keeps the standard output of the
copy scripts connected to its own standard output.

Windows / Cygwin notes:
-----------------------
Make sure you use the Cygwin's version of OpenSSH, not the Windows' version.

As of OpenSSH_8.3p1, the SSH connection multiplexing on Cygwin (still) doesn't
seem to work, not even in the Proxy Multiplexing mode (-O proxy).

To avoid repeated entering of passwords, use the SSH Public Key authentication.

Other SSH/SCP-related remarks:
------------------------------
If the path of the remote <sourceDir> or <backupDir> is given relative, then it
is relative to the SSH login directory of the user on the remote host.

To use a different port, use also the options "--sshOptions" and "--scpOptions"
to pass the options "-p <port>" to SSH and "-P <port>" to SCP.

The SCP commands that copy from remote to local may require the "-T" option
to disable the (broken?) SCP-internal check that results in false findings like
"filename does not match request" or "invalid brace pattern". Use "--scpOptions"
to pass the "-T" option to SCP.

The individual option words in <sshOptions> and <scpOptions> are separated by
spaces. Neither SSH nor SCP allows/requires words in their command-line options
that would themselves contain spaces or metacharacters that would undergo
additional shell expansions, also Zaloha does not contain any sophisticated
handling of <sshOptions> and <scpOptions>.

The option "--scpExecOpt" can be used to override <scpOptions> specially for
the SCP commands used during the execution phase. If the option "--scpExecOpt"
is not given, <scpOptions> applies to all SCP commands (= to those used in the
analysis phase as well as to those used in the execution phase).

Zaloha does not use the "-p" option of scp to preserve times of files, because
this option has a side effect (that is not always wanted) of preserving the
modes too. Explicit TOUCH commands in the post-copy scripts are used instead.
They preserve the modification times (only).

Eventual "at" signs (@) and colons (:) contained in directory names should not
cause misinterpretations as users and hosts by SCP, because Zaloha prepends
relative paths by "./" and SCP does not interpret "at" signs (@) and colons (:)
after first slash in file/directory names.

###########################################################

ADVANCED USE OF ZALOHA - COMPARING CONTENTS OF FILES

First, let's make it clear that comparing contents of files will increase the
runtime dramatically, because instead of reading just the directory data,
the files themselves must be read.

ALTERNATIVE 1: option "--byteByByte" (suitable if both filesystems are local)

Option "--byteByByte" forces Zaloha to compare "byte by byte" files that appear
identical (more precisely, files for which either "no action" (OK) or just
"update of attributes" (ATTR) has been prepared). If additional updates of files
result from this comparison, they will be executed in step Exec5.

ALTERNATIVE 2: option "--sha256" (compare contents of files via SHA-256 hashes)

There is an almost 100% security that files are identical if they have equal
sizes and SHA-256 hashes. The "--sha256" option instructs Zaloha to prepare
FIND expressions that, besides collecting the usual metadata via the -printf
operand, cause SHA256SUM to be invoked on each file to calculate the SHA-256
hash. These calculated hashes are contained in extra records in files 310 and
320, and AWKCLEANER merges them into the regular records in the cleaned files
330 and 340 (the SHA-256 hashes go into column 13).

If additional updates of files result from comparisons of SHA-256 hashes,
they will be executed in step Exec5 (same principle as for the "--byteByByte"
option).

Additionally, Zaloha handles situations where the files have identical sizes
and SHA-256 hashes, but different modification times: it then prevents copying
of such files and only aligns their modification times (ATTR:T).

The "--sha256" option has been developed for the Remote Modes, where the files
to be compared reside on different hosts: The SHA-256 hashes are calculated
on the respective hosts and for the comparisons of file contents, just the
hashes are transferred over the network, not the files themselves.

The "--sha256" option is not limited to the Remote Modes - it can be used in
the Local Mode too. Having CSV metadata that contains the SHA-256 hashes may
be useful for other purposes as well, e.g. for de-duplication of files by
content in the source directory: By sorting the CSV file 330 by the SHA-256
hashes (column 13) one obtains a CSV file where the files with identical
contents are located in adjacent records.

###########################################################

ADVANCED USE OF ZALOHA - COPYING FILES IN PARALLEL

First, let's clarify when parallel operations do not make sense: When copying
files locally, even one single process will probably fully utilize the available
bus capacity. In such cases, copying files in parallel does not make sense.

On the contrary, imagine what happens when a process copies a small file over
a network with high latency: sending out the small file takes microseconds,
but waiting for the network round-trip to finish takes milliseconds. Also, the
process is idle most of the time, and the network capacity is under-utilized.
In such cases, also typically when many small files are copied over a network,
running the copy commands in parallel will speed up the process significantly.

Zaloha provides support for parallel operations of up to 8 parallel processes
(constant MAXPARALLEL). How to utilize this support:

Let's take the script 622_exec2_copy.sh as an example: Make 8 copies of the
script. In the header of the first copy, keep only CP1, TOUCH1 (or SCP1)
assigned to real commands, and assign all other "command variables" to the empty
command (shell builtin ":"). Adjust the other copies accordingly. This way,
each of the 8 copies will process only its own portion of files, so they can be
run in parallel.

These manipulations should, of course, be automated by a wrapper script: The
wrapper script should invoke Zaloha with the "--noExec" and "--no622Hdr"
options, also Zaloha prepares the 622 script without header (i.e. body only).
The wrapper script should prepare the 8 different headers and use them
with the header-less 622 script (of which only one copy is needed then).

###########################################################

ADVANCED USE OF ZALOHA - TECHNICAL INTEGRATION OPTIONS

Zaloha contains several options to make technical integrations easy. In the
extreme case, Zaloha can be used as a mere "difference engine" which takes
the FIND data from <sourceDir> and/or <backupDir> as inputs and produces the
CSV metadata and the Exec1/2/3/4/5 scripts as outputs.

First useful option is "--noDirChecks": This switches off the checks for
existence of <sourceDir> and <backupDir>.

In Local Mode, if <backupDir> is not available locally, it is necessary to use
the "--metaDir" option to place the Zaloha metadata directory to a location
accessible to Zaloha.

Next useful options are "--noFindSource" and/or "--noFindBackup": They instruct
Zaloha to not run FIND on <sourceDir> and/or <backupDir>, but use externally
supplied CSV metadata files 310 and/or 320 instead. This means that these files
must be produced externally and downloaded to the Zaloha metadata directory
before invoking Zaloha. These files must, of course, have the same names and
contents as the CSV metadata files that would otherwise be produced by the
scripts 210 and/or 220.

The "--noFindSource" and/or "--noFindBackup" options are also useful when
network-mounted directories are available locally, but running FIND on them is
slow. Running the FINDs directly on the respective file servers in SSH sessions
should be much quicker.

The "--noExec" option can be used to prevent execution of the Exec1/2/3/4/5
scripts by Zaloha itself.

Last set of useful options are "--no610Hdr" through "--no653Hdr". They instruct
Zaloha to produce header-less Exec1/2/3/4/5 scripts (i.e. bodies only).
The headers normally contain definitions used in the bodies of the scripts.
Header-less scripts can be easily used with alternative headers that contain
different definitions. This gives much flexibility:

The "command variables" can be assigned to different commands or own shell
functions. The "directory variables" sourceDir and backupDir can be re-assigned
as needed, e.g. to empty strings (which will cause the paths passed to the
commands to be not prefixed by <sourceDir> and <backupDir>).

###########################################################

CYBER SECURITY TOPICS

Standard security practices should be followed on environments exposed to
potential attackers: Potential attackers should not be allowed to modify the
command line that invokes Zaloha, the PATH variable, BASH init scripts or other
items that may influence how Zaloha works and invokes operating system commands.

Further, the following security threats arise from backup of a directory that is
writable by a potential attacker:

Backup media overflow attack via hardlinks
------------------------------------------
The attacker might hard-link a huge file many times, hoping that the backup
program writes each link as a physical copy to the backup media ...

Mitigation with Zaloha: Perform hardlink detection (use the "--detectHLinksS"
option)

Backup media overflow attack via symbolic links
-----------------------------------------------
The attacker might create many symbolic links pointing to directories with huge
contents (or to huge files), hoping that the backup program writes the contents
pointed to by each such link as a physical copy to the backup media ...

Mitigation with Zaloha: Do not follow symbolic links on <sourceDir> (do not use
                        the "--followSLinksS" option)

Unauthorized access via symbolic links
--------------------------------------
The attacker might create symbolic links to locations to which he has no access,
hoping that within the restore process (which he might explicitly request for
this purpose) the linked contents will be restored to his home directory ...

Mitigation with Zaloha: Do not follow symbolic links on <sourceDir> (do not use
                        the "--followSLinksS" option)

Privilege escalation attacks
----------------------------
The attacker might create a rogue executable program in his home directory with
the SetUID and/or SetGID bits set, hoping that within the backup process (or
within the restore process, which he might explicitly request for this purpose),
the user/group ownership of his rogue program changes to a user/group with
higher privileges (ideally root), the SetUID and/or SetGID bits will be restored
and he will have access to this program ...

Mitigation with Zaloha: Prevent this scenario. Be specially careful with options
                        "--pMode" and "--pRevMode" and with the restore script
                        860_restore_mode.sh

Attack on Zaloha metadata
-------------------------
The attacker might manipulate files in the Metadata directory of Zaloha, or in
the Temporary Metadata directory of Zaloha, while Zaloha runs ...

Mitigation with Zaloha: Make sure that the files in the Metadata directories
are not writeable/executable by other users (set up correct umasks, review
ownerships and modes of files that already exist).

Shell code injection attacks
----------------------------
The attacker might create a file in his home directory with a name that is
actually a rogue shell code (e.g. '; rm -Rf ..'), hoping that the shell code
will, due to some program flaw, be executed by a user with higher privileges ...

Mitigation with Zaloha: Currently not aware of such vulnerability within Zaloha.
                        If found, please open a high priority issue on GitHub.

###########################################################
ZALOHADOCU
}

# DEFINITIONS OF INDIVIDUAL FILES IN METADATA DIRECTORY OF ZALOHA

metaDirDefaultBase='.Zaloha_metadata'
metaDirTempDefaultBase='.Zaloha_metadata_temp'

f000Base='000_parameters.csv'        # parameters under which Zaloha was invoked and internal variables

f100Base='100_awkpreproc.awk'        # AWK preprocessor for other AWK programs
f102Base='102_xtrace2term.awk'       # AWK program for terminal display of shell traces (with control characters escaped), color handling
f104Base='104_actions2term.awk'      # AWK program for terminal display of actions (with control characters escaped), color handling
f106Base='106_parser.awk'            # AWK program for parsing of FIND operands and construction of FIND commands
f110Base='110_cleaner.awk'           # AWK program for handling of raw outputs of FIND (escape tabs and newlines, field 14 handling, SHA-256 record handling)
f130Base='130_checker.awk'           # AWK program for checking
f150Base='150_hlinks.awk'            # AWK program for hardlink detection (inode-deduplication)
f170Base='170_diff.awk'              # AWK program for differences processing
f190Base='190_postproc.awk'          # AWK program for differences post-processing and splitting off Exec1 and Exec4 actions

f200Base='200_find_lastrun.sh'       # shellscript for FIND on <metaDir>/999_mark_executed
f205Base='205_read_slink.sh'         # auxiliary script to obtain target paths of symbolic links that contain three or more consecutive slashes
f210Base='210_find_source.sh'        # shellscript for FIND on <sourceDir>
f220Base='220_find_backup.sh'        # shellscript for FIND on <backupDir>

f300Base='300_lastrun.csv'           # output of FIND on <metaDir>/999_mark_executed
f310Base='310_source_raw.csv'        # raw output of FIND on <sourceDir>
f320Base='320_backup_raw.csv'        # raw output of FIND on <backupDir>
f330Base='330_source_clean.csv'      # <sourceDir> metadata clean (escaped tabs and newlines, field 14 handling, SHA-256 record handling)
f340Base='340_backup_clean.csv'      # <backupDir> metadata clean (escaped tabs and newlines, field 14 handling, SHA-256 record handling)
f350Base='350_source_s_hlinks.csv'   # <sourceDir> metadata sorted for hardlink detection (inode-deduplication)
f360Base='360_source_hlinks.csv'     # <sourceDir> metadata after hardlink detection (inode-deduplication)
f370Base='370_union_s_diff.csv'      # <sourceDir> + <backupDir> metadata united and sorted for differences processing
f380Base='380_diff.csv'              # result of differences processing
f390Base='390_diff_r_post.csv'       # differences result reverse sorted for post-processing and splitting off Exec1 and Exec4 actions

f405Base='405_select23.awk'          # AWK program for selection of Exec2 and Exec3 actions
f410Base='410_exec1.awk'             # AWK program for preparation of shellscripts for Exec1 and Exec4
f420Base='420_exec2.awk'             # AWK program for preparation of shellscripts for Exec2 and Exec5
f430Base='430_exec3.awk'             # AWK program for preparation of shellscript for Exec3
f490Base='490_touch.awk'             # AWK program for preparation of shellscript to touch file 999_mark_executed

f500Base='500_target_r.csv'          # differences result after splitting off Exec1 and Exec4 actions (= target state) reverse sorted
f505Base='505_target.csv'            # target state (includes Exec2, Exec3 (and Exec5 from SHA-256 comparing) actions) of synchronized directories
f510Base='510_exec1.csv'             # Exec1 actions (reverse sorted)
f520Base='520_exec2.csv'             # Exec2 actions
f530Base='530_exec3.csv'             # Exec3 actions
f540Base='540_exec4.csv'             # Exec4 actions (reverse sorted)
f550Base='550_exec5.csv'             # Exec5 actions (from byte by byte comparing of files that appear identical or from SHA-256 comparing)
f555Base='555_byte_by_byte.csv'      # result of byte by byte comparing of files that appear identical

f610Base='610_exec1.sh'              # shellscript for Exec1 (in Remote Backup Mode to be executed on remote side in one batch)
f621Base='621_exec2_pre_copy.sh'     # shellscript for Exec2 pre-copy actions (make directories and unlink files, in Remote Backup Mode to be executed on remote side in one batch)
f622Base='622_exec2_copy.sh'         # shellscript for Exec2 copy actions (CP or SCP commands to be executed locally)
f623Base='623_exec2_post_copy.sh'    # shellscript for Exec2 post-copy actions (user+group ownerships and modes, in Remote Backup Mode to be executed on remote side in one batch)
f631Base='631_exec3_pre_copy.sh'     # shellscript for Exec3 pre-copy actions (REV_EXISTS checks, make directories, in Remote Source Mode to be executed on remote side in one batch)
f632Base='632_exec3_copy.sh'         # shellscript for Exec3 copy actions (CP or SCP commands to be executed locally)
f633Base='633_exec3_post_copy.sh'    # shellscript for Exec3 post-copy actions (user+group ownerships and modes, in Remote Source Mode to be executed on remote side in one batch)
f640Base='640_exec4.sh'              # shellscript for Exec4 (in Remote Backup Mode to be executed on remote side in one batch)
f651Base='651_exec5_pre_copy.sh'     # shellscript for Exec5 pre-copy actions (make directories and unlink files, in Remote Backup Mode to be executed on remote side in one batch)
f652Base='652_exec5_copy.sh'         # shellscript for Exec5 copy actions (CP or SCP commands to be executed locally)
f653Base='653_exec5_post_copy.sh'    # shellscript for Exec5 post-copy actions (user+group ownerships and modes, in Remote Backup Mode to be executed on remote side in one batch)
f690Base='690_touch.sh'              # shellscript to touch file 999_mark_executed

f700Base='700_restore.awk'           # AWK program for preparation of shellscripts for the case of restore

f800Base='800_restore_dirs.sh'       # for the case of restore: shellscript to restore directories
f810Base='810_restore_files.sh'      # for the case of restore: shellscript to restore files
f820Base='820_restore_sym_links.sh'  # for the case of restore: shellscript to restore symbolic links
f830Base='830_restore_hardlinks.sh'  # for the case of restore: shellscript to restore hardlinks
f840Base='840_restore_user_own.sh'   # for the case of restore: shellscript to restore user ownerships
f850Base='850_restore_group_own.sh'  # for the case of restore: shellscript to restore group ownerships
f860Base='860_restore_mode.sh'       # for the case of restore: shellscript to restore modes (permission bits)
f870Base='870_restore_mtime.sh'      # for the case of restore: shellscript to restore modification times

f999Base='999_mark_executed'         # empty touchfile marking execution of actions

###########################################################

set -u
set -e
set -o pipefail

function error_exit {
  printf 'Zaloha2.sh: %s\n' "${1}" >&2
  exit 1
}

trap 'error_exit "Error on line ${LINENO}"' ERR

pidBackgroundJob=

function cleanup_background_job {
  set +e
  trap - ERR
  if [ '' != "${pidBackgroundJob}" ]; then
    tmpVal="$(jobs -r)"
    if [ '' != "${tmpVal}" ]; then
      printf 'Zaloha2.sh: Killing background job PGID: %s\n' "${pidBackgroundJob}"
      kill -SIGTERM -- "-${pidBackgroundJob}"
    else
      printf 'Zaloha2.sh: Background job PGID: %s does not exist anymore\n' "${pidBackgroundJob}"
    fi
    pidBackgroundJob=
  fi
}

trap 'cleanup_background_job' EXIT

function opt_dupli_check {
  if [ ${1} -eq 1 ]; then
    error_exit "Option ${2} passed in two or more times"
  fi
}

function start_progress {
  if [ ${noProgress} -eq 0 ]; then
    printf '    %s %s' "${1}" "${DOTS60:1:$(( 53 - ${#1} ))}"
    progressCurrColNo=58
  fi
}

function start_progress_by_chars {
  if [ ${noProgress} -eq 0 ]; then
    printf '    %s ' "${1}"
    (( progressCurrColNo = ${#1} + 5 ))
  fi
}

function progress_char {
  if [ ${noProgress} -eq 0 ]; then
    if [ ${progressCurrColNo} -ge 80 ]; then
      printf '\n    '
      progressCurrColNo=4
    fi
    printf '%s' "${1}"
    (( progressCurrColNo ++ ))
  fi
}

function stop_progress {
  if [ ${noProgress} -eq 0 ]; then
    if [ ${progressCurrColNo} -gt 58 ]; then
      printf '\n    '
      progressCurrColNo=4
    fi
    printf '%s done.\n' "${BLANKS60:1:$(( 58 - ${progressCurrColNo} ))}"
  fi
}

function progress_scp_meta {
  if [ ${noProgress} -eq 0 ]; then
    if [ '>' == "${1}" ]; then
      printf '%s%s\n' "${DASH20}" "${1}"
    else
      printf '%s%s\n' "${1}" "${DASH20}"
    fi
  fi
}

function files_not_prepared {
  for file in "${@}"
  do
    if [ -e "${file}" ]; then
      rm -f "${file}"
    fi
  done
}

function optim_csv_after_use {
  if [ ${optimCSV} -eq 1 ]; then
    rm -f "${@}"
  fi
}

TAB=$'\t'
NLINE=$'\n'
BSLASHPATTERN='\\'
QUOTEPATTERN='\'"'"
QUOTEESC="'"'"'"'"'"'"'"
QUOTE="'"
ASTERISKPATTERN='\*'
ASTERISK='*'
QUESTIONMARKPATTERN='\?'
QUESTIONMARK='?'
LBRACKETPATTERN='\['
LBRACKET='['
RBRACKETPATTERN='\]'
RBRACKET=']'
CNTRLPATTERN='[[:cntrl:]]'
TRIPLETDSEP='///d/'  # placeholder in FIND patterns for <sourceDir> or <backupDir> followed by directory separator
TRIPLETT='///t'      # escape for tab
TRIPLETN='///n'      # escape for newline
TRIPLETB='///b'      # escape for backslash
TRIPLETC='///c'      # display of control characters on terminal
TRIPLET='///'        # escape sequence, leading field, terminator field

FSTAB=$'\t'
TERMNORM=$'\033''[0m'
TERMBLUE=$'\033''[94m'
printf -v BLANKS20 '%20s' ' '
DASH20="${BLANKS20// /-}"
printf -v BLANKS60 '%60s' ' '
DOTS60="${BLANKS60// /.}"
RECFMT='%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'

###########################################################

sourceDir=
sourceDirPassed=0
backupDir=
backupDirPassed=0
sourceUserHost=
remoteSource=0
backupUserHost=
remoteBackup=0
sshOptions=
sshOptionsPassed=0
scpOptions=
scpOptionsPassed=0
scpExecOpt=
scpExecOptPassed=0
findSourceOps=
findGeneralOps=
findGeneralOpsPassed=0
findParallel=0
noExec=0
noRemove=0
revNew=0
revUp=0
detectHLinksS=0
ok2s=0
ok3600s=0
byteByByte=0
sha256=0
noUnlink=0
extraTouch=0
cpOptions=
cpOptionsPassed=0
cpRestoreOpt=
cpRestoreOptPassed=0
pUser=0
pGroup=0
pMode=0
pRevUser=0
pRevGroup=0
pRevMode=0
followSLinksS=0
followSLinksB=0
syncSLinks=0
noWarnSLinks=0
noRestore=0
optimCSV=0
metaDir=
metaDirPassed=0
metaDirTemp=
metaDirTempPassed=0
noDirChecks=0
noLastRun=0
noIdentCheck=0
noFindSource=0
noFindBackup=0
no610Hdr=0
no621Hdr=0
no622Hdr=0
no623Hdr=0
no631Hdr=0
no632Hdr=0
no633Hdr=0
no640Hdr=0
no651Hdr=0
no652Hdr=0
no653Hdr=0
noR800Hdr=0
noR810Hdr=0
noR820Hdr=0
noR830Hdr=0
noR840Hdr=0
noR850Hdr=0
noR860Hdr=0
noR870Hdr=0
noProgress=0
color=0
mawk=0
lTest=0
help=0

for tmpVal in "${@}"
do
  case "${tmpVal}" in
    --sourceDir=*)       opt_dupli_check ${sourceDirPassed} "${tmpVal%%=*}";   sourceDir="${tmpVal#*=}";  sourceDirPassed=1 ;;
    --backupDir=*)       opt_dupli_check ${backupDirPassed} "${tmpVal%%=*}";   backupDir="${tmpVal#*=}";  backupDirPassed=1 ;;
    --sourceUserHost=*)  opt_dupli_check ${remoteSource} "${tmpVal%%=*}";      sourceUserHost="${tmpVal#*=}";  remoteSource=1 ;;
    --backupUserHost=*)  opt_dupli_check ${remoteBackup} "${tmpVal%%=*}";      backupUserHost="${tmpVal#*=}";  remoteBackup=1 ;;
    --sshOptions=*)      opt_dupli_check ${sshOptionsPassed} "${tmpVal%%=*}";  sshOptions="${tmpVal#*=}";  sshOptionsPassed=1 ;;
    --scpOptions=*)      opt_dupli_check ${scpOptionsPassed} "${tmpVal%%=*}";  scpOptions="${tmpVal#*=}";  scpOptionsPassed=1 ;;
    --scpExecOpt=*)      opt_dupli_check ${scpExecOptPassed} "${tmpVal%%=*}";  scpExecOpt="${tmpVal#*=}";  scpExecOptPassed=1 ;;
    --findSourceOps=*)   findSourceOps+="${tmpVal#*=} " ;;
    --findGeneralOps=*)  findGeneralOps+="${tmpVal#*=} ";  findGeneralOpsPassed=1 ;;
    --findParallel)      opt_dupli_check ${findParallel} "${tmpVal}";   findParallel=1 ;;
    --noExec)            opt_dupli_check ${noExec} "${tmpVal}";         noExec=1 ;;
    --noRemove)          opt_dupli_check ${noRemove} "${tmpVal}";       noRemove=1 ;;
    --revNew)            opt_dupli_check ${revNew} "${tmpVal}";         revNew=1 ;;
    --revUp)             opt_dupli_check ${revUp} "${tmpVal}";          revUp=1 ;;
    --detectHLinksS)     opt_dupli_check ${detectHLinksS} "${tmpVal}";  detectHLinksS=1 ;;
    --ok2s)              opt_dupli_check ${ok2s} "${tmpVal}";           ok2s=1 ;;
    --ok3600s)           opt_dupli_check ${ok3600s} "${tmpVal}";        ok3600s=1 ;;
    --byteByByte)        opt_dupli_check ${byteByByte} "${tmpVal}";     byteByByte=1 ;;
    --sha256)            opt_dupli_check ${sha256} "${tmpVal}";         sha256=1 ;;
    --noUnlink)          opt_dupli_check ${noUnlink} "${tmpVal}";       noUnlink=1 ;;
    --extraTouch)        opt_dupli_check ${extraTouch} "${tmpVal}";     extraTouch=1 ;;
    --cpOptions=*)       opt_dupli_check ${cpOptionsPassed} "${tmpVal%%=*}";     cpOptions="${tmpVal#*=}";     cpOptionsPassed=1 ;;
    --cpRestoreOpt=*)    opt_dupli_check ${cpRestoreOptPassed} "${tmpVal%%=*}";  cpRestoreOpt="${tmpVal#*=}";  cpRestoreOptPassed=1 ;;
    --pUser)             opt_dupli_check ${pUser} "${tmpVal}";          pUser=1 ;;
    --pGroup)            opt_dupli_check ${pGroup} "${tmpVal}";         pGroup=1 ;;
    --pMode)             opt_dupli_check ${pMode} "${tmpVal}";          pMode=1 ;;
    --pRevUser)          opt_dupli_check ${pRevUser} "${tmpVal}";       pRevUser=1 ;;
    --pRevGroup)         opt_dupli_check ${pRevGroup} "${tmpVal}";      pRevGroup=1 ;;
    --pRevMode)          opt_dupli_check ${pRevMode} "${tmpVal}";       pRevMode=1 ;;
    --followSLinksS)     opt_dupli_check ${followSLinksS} "${tmpVal}";  followSLinksS=1 ;;
    --followSLinksB)     opt_dupli_check ${followSLinksB} "${tmpVal}";  followSLinksB=1 ;;
    --syncSLinks)        opt_dupli_check ${syncSLinks} "${tmpVal}";     syncSLinks=1 ;;
    --noWarnSLinks)      opt_dupli_check ${noWarnSLinks} "${tmpVal}";   noWarnSLinks=1 ;;
    --noRestore)         opt_dupli_check ${noRestore} "${tmpVal}";      noRestore=1 ;;
    --optimCSV)          opt_dupli_check ${optimCSV} "${tmpVal}";       optimCSV=1 ;;
    --metaDir=*)         opt_dupli_check ${metaDirPassed} "${tmpVal%%=*}";      metaDir="${tmpVal#*=}";      metaDirPassed=1 ;;
    --metaDirTemp=*)     opt_dupli_check ${metaDirTempPassed} "${tmpVal%%=*}";  metaDirTemp="${tmpVal#*=}";  metaDirTempPassed=1 ;;
    --noDirChecks)       opt_dupli_check ${noDirChecks} "${tmpVal}";    noDirChecks=1 ;;
    --noLastRun)         opt_dupli_check ${noLastRun} "${tmpVal}";      noLastRun=1 ;;
    --noIdentCheck)      opt_dupli_check ${noIdentCheck} "${tmpVal}";   noIdentCheck=1 ;;
    --noFindSource)      opt_dupli_check ${noFindSource} "${tmpVal}";   noFindSource=1 ;;
    --noFindBackup)      opt_dupli_check ${noFindBackup} "${tmpVal}";   noFindBackup=1 ;;
    --no610Hdr)          opt_dupli_check ${no610Hdr} "${tmpVal}";       no610Hdr=1 ;;
    --no621Hdr)          opt_dupli_check ${no621Hdr} "${tmpVal}";       no621Hdr=1 ;;
    --no622Hdr)          opt_dupli_check ${no622Hdr} "${tmpVal}";       no622Hdr=1 ;;
    --no623Hdr)          opt_dupli_check ${no623Hdr} "${tmpVal}";       no623Hdr=1 ;;
    --no631Hdr)          opt_dupli_check ${no631Hdr} "${tmpVal}";       no631Hdr=1 ;;
    --no632Hdr)          opt_dupli_check ${no632Hdr} "${tmpVal}";       no632Hdr=1 ;;
    --no633Hdr)          opt_dupli_check ${no633Hdr} "${tmpVal}";       no633Hdr=1 ;;
    --no640Hdr)          opt_dupli_check ${no640Hdr} "${tmpVal}";       no640Hdr=1 ;;
    --no651Hdr)          opt_dupli_check ${no651Hdr} "${tmpVal}";       no651Hdr=1 ;;
    --no652Hdr)          opt_dupli_check ${no652Hdr} "${tmpVal}";       no652Hdr=1 ;;
    --no653Hdr)          opt_dupli_check ${no653Hdr} "${tmpVal}";       no653Hdr=1 ;;
    --noR800Hdr)         opt_dupli_check ${noR800Hdr} "${tmpVal}";      noR800Hdr=1 ;;
    --noR810Hdr)         opt_dupli_check ${noR810Hdr} "${tmpVal}";      noR810Hdr=1 ;;
    --noR820Hdr)         opt_dupli_check ${noR820Hdr} "${tmpVal}";      noR820Hdr=1 ;;
    --noR830Hdr)         opt_dupli_check ${noR830Hdr} "${tmpVal}";      noR830Hdr=1 ;;
    --noR840Hdr)         opt_dupli_check ${noR840Hdr} "${tmpVal}";      noR840Hdr=1 ;;
    --noR850Hdr)         opt_dupli_check ${noR850Hdr} "${tmpVal}";      noR850Hdr=1 ;;
    --noR860Hdr)         opt_dupli_check ${noR860Hdr} "${tmpVal}";      noR860Hdr=1 ;;
    --noR870Hdr)         opt_dupli_check ${noR870Hdr} "${tmpVal}";      noR870Hdr=1 ;;
    --noProgress)        opt_dupli_check ${noProgress} "${tmpVal}";     noProgress=1 ;;
    --color)             opt_dupli_check ${color} "${tmpVal}";          color=1 ;;
    --mawk)              opt_dupli_check ${mawk} "${tmpVal}";           mawk=1 ;;
    --lTest)             opt_dupli_check ${lTest} "${tmpVal}";          lTest=1 ;;
    --help)              opt_dupli_check ${help} "${tmpVal}";           help=1 ;;
    *) error_exit "Unknown option ${tmpVal//${CNTRLPATTERN}/${TRIPLETC}}, get help via Zaloha2.sh --help" ;;
  esac
done

if [ ${help} -eq 1 ]; then
  zaloha_docu
  exit 0
fi

if [ ${remoteSource} -eq 1 ] && [ ${remoteBackup} -eq 1 ]; then
  error_exit 'Options --sourceUserHost and --backupUserHost may not be used together'
fi
if [ ${remoteSource} -eq 1 ] || [ ${remoteBackup} -eq 1 ]; then
  if [ ${byteByByte} -eq 1 ]; then
    error_exit 'Option --byteByByte may not be used in Remote Source or Remote Backup Mode'
  fi
  if [ ${extraTouch} -eq 1 ]; then
    error_exit 'Option --extraTouch may not be used in Remote Source or Remote Backup Mode'
  fi
  if [ ${cpOptionsPassed} -eq 1 ]; then
    error_exit 'Option --cpOptions may not be used in Remote Source or Remote Backup Mode'
  fi
  if [ ${cpRestoreOptPassed} -eq 1 ]; then
    error_exit 'Option --cpRestoreOpt may not be used in Remote Source or Remote Backup Mode'
  fi
else
  if [ ${sshOptionsPassed} -eq 1 ]; then
    error_exit 'Option --sshOptions may be used only in Remote Source or Remote Backup Mode'
  fi
  if [ ${scpOptionsPassed} -eq 1 ]; then
    error_exit 'Option --scpOptions may be used only in Remote Source or Remote Backup Mode'
  fi
  if [ ${scpExecOptPassed} -eq 1 ]; then
    error_exit 'Option --scpExecOpt may be used only in Remote Source or Remote Backup Mode'
  fi
  if [ ${findParallel} -eq 1 ]; then
    error_exit 'Option --findParallel may be used only in Remote Source or Remote Backup Mode'
  fi
  if [ ${metaDirTempPassed} -eq 1 ]; then
    error_exit 'Option --metaDirTemp may be used only in Remote Source or Remote Backup Mode'
  fi
fi
if [ ${byteByByte} -eq 1 ] && [ ${sha256} -eq 1 ]; then
  error_exit 'Options --byteByByte and --sha256 may not be used together'
fi
if [ ${revNew} -eq 1 ] && [ ${noLastRun} -eq 1 ]; then
  error_exit 'Option --revNew may not be used if option --noLastRun is given'
fi
if [ ${noFindSource} -eq 1 ] || [ ${noFindBackup} -eq 1 ]; then
  if [ ${findParallel} -eq 1 ]; then
    error_exit 'Option --findParallel may not be used if options --noFindSource and/or --noFindBackup are given'
  fi
fi
if [ ${noExec} -eq 0 ]; then
  if [ ${no610Hdr} -eq 1 ] || \
     [ ${no621Hdr} -eq 1 ] || [ ${no622Hdr} -eq 1 ] || [ ${no623Hdr} -eq 1 ] || \
     [ ${no631Hdr} -eq 1 ] || [ ${no632Hdr} -eq 1 ] || [ ${no633Hdr} -eq 1 ] || \
     [ ${no640Hdr} -eq 1 ] || \
     [ ${no651Hdr} -eq 1 ] || [ ${no652Hdr} -eq 1 ] || [ ${no653Hdr} -eq 1 ];
  then
    error_exit 'Options --no610Hdr through --no653Hdr can be used only together with option --noExec'
  fi
fi

scpMetaOpt="${scpOptions}"
if [ ${noProgress} -eq 1 ]; then
  scpMetaOpt="-q ${scpMetaOpt}"
fi

if [ ${scpExecOptPassed} -eq 0 ]; then
  scpExecOpt="${scpOptions}"
fi
scpExecOptAwk="${scpExecOpt//${BSLASHPATTERN}/${TRIPLETB}}"

cpExecOpt="${cpOptions}"
if [ ${cpOptionsPassed} -eq 0 ] && [ ${extraTouch} -eq 0 ]; then
  cpExecOpt='--preserve=timestamps'
fi
cpExecOptAwk="${cpExecOpt//${BSLASHPATTERN}/${TRIPLETB}}"

if [ ${cpRestoreOptPassed} -eq 0 ]; then
  cpRestoreOpt="${cpOptions}"
fi
cpRestoreOptAwk="${cpRestoreOpt//${BSLASHPATTERN}/${TRIPLETB}}"

if [ ${mawk} -eq 1 ]; then
  awk='mawk'
  awkNoBuf='mawk -W interactive'
elif [ ${lTest} -eq 1 ]; then
  awk='awk -Lfatal'
  awkNoBuf='awk -Lfatal'
else
  awk='awk'
  awkNoBuf='awk'
fi

###########################################################

if [ '' == "${sourceDir}" ]; then
  error_exit '<sourceDir> is mandatory, get help via Zaloha2.sh --help'
fi
if [ "${sourceDir/${TRIPLET}/}" != "${sourceDir}" ]; then
  error_exit "<sourceDir> contains the directory separator triplet (${TRIPLET})"
fi
if [ '/' != "${sourceDir:0:1}" ] && [ './' != "${sourceDir:0:2}" ]; then
  sourceDir="./${sourceDir}"
fi
if [ '/' != "${sourceDir: -1:1}" ]; then
  sourceDir="${sourceDir}/"
fi
sourceDirAwk="${sourceDir//${BSLASHPATTERN}/${TRIPLETB}}"
sourceDirPattAwk="${sourceDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
sourceDirPattAwk="${sourceDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
sourceDirPattAwk="${sourceDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
sourceDirPattAwk="${sourceDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
sourceDirPattAwk="${sourceDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
sourceDirScp="${QUOTE}${sourceDir//${QUOTEPATTERN}/${QUOTEESC}}${QUOTE}"
sourceDirEsc="${sourceDir//${TAB}/${TRIPLETT}}"
sourceDirEsc="${sourceDirEsc//${NLINE}/${TRIPLETN}}"
if [ ${color} -eq 1 ]; then
  sourceUserHostDirTerm="${sourceDirEsc//${CNTRLPATTERN}/${TERMBLUE}${TRIPLETC}${TERMNORM}}"
  sourceUserHostDirTerm="${sourceUserHostDirTerm//${TRIPLETT}/${TERMBLUE}${TRIPLETT}${TERMNORM}}"
  sourceUserHostDirTerm="${sourceUserHostDirTerm//${TRIPLETN}/${TERMBLUE}${TRIPLETN}${TERMNORM}}"
else
  sourceUserHostDirTerm="${sourceDirEsc//${CNTRLPATTERN}/${TRIPLETC}}"
fi

###########################################################

if [ '' == "${backupDir}" ]; then
  error_exit '<backupDir> is mandatory, get help via Zaloha2.sh --help'
fi
if [ "${backupDir/${TRIPLET}/}" != "${backupDir}" ]; then
  error_exit "<backupDir> contains the directory separator triplet (${TRIPLET})"
fi
if [ '/' != "${backupDir:0:1}" ] && [ './' != "${backupDir:0:2}" ]; then
  backupDir="./${backupDir}"
fi
if [ '/' != "${backupDir: -1:1}" ]; then
  backupDir="${backupDir}/"
fi
backupDirAwk="${backupDir//${BSLASHPATTERN}/${TRIPLETB}}"
backupDirPattAwk="${backupDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
backupDirPattAwk="${backupDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
backupDirPattAwk="${backupDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
backupDirPattAwk="${backupDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
backupDirPattAwk="${backupDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
backupDirScp="${QUOTE}${backupDir//${QUOTEPATTERN}/${QUOTEESC}}${QUOTE}"
backupDirEsc="${backupDir//${TAB}/${TRIPLETT}}"
backupDirEsc="${backupDirEsc//${NLINE}/${TRIPLETN}}"
if [ ${color} -eq 1 ]; then
  backupUserHostDirTerm="${backupDirEsc//${CNTRLPATTERN}/${TERMBLUE}${TRIPLETC}${TERMNORM}}"
  backupUserHostDirTerm="${backupUserHostDirTerm//${TRIPLETT}/${TERMBLUE}${TRIPLETT}${TERMNORM}}"
  backupUserHostDirTerm="${backupUserHostDirTerm//${TRIPLETN}/${TERMBLUE}${TRIPLETN}${TERMNORM}}"
else
  backupUserHostDirTerm="${backupDirEsc//${CNTRLPATTERN}/${TRIPLETC}}"
fi

###########################################################

if [ ${remoteSource} -eq 1 ]; then
  if [ '' == "${sourceUserHost}" ]; then
    error_exit '<sourceUserHost> is mandatory if --sourceUserHost option is given'
  fi
  sourceUserHostDirTerm="${sourceUserHost}:${sourceUserHostDirTerm}"
fi
sourceUserHostAwk="${sourceUserHost//${BSLASHPATTERN}/${TRIPLETB}}"

if [ ${remoteBackup} -eq 1 ]; then
  if [ '' == "${backupUserHost}" ]; then
    error_exit '<backupUserHost> is mandatory if --backupUserHost option is given'
  fi
  backupUserHostDirTerm="${backupUserHost}:${backupUserHostDirTerm}"
fi
backupUserHostAwk="${backupUserHost//${BSLASHPATTERN}/${TRIPLETB}}"

###########################################################

tmpVal="${findSourceOps//${TRIPLETDSEP}/M}"
if [ "${tmpVal/${TRIPLET}/}" != "${tmpVal}" ]; then
  error_exit "<findSourceOps> contains the directory separator triplet (${TRIPLET})"
fi
findSourceOpsAwk="${findSourceOps//${BSLASHPATTERN}/${TRIPLETB}}"
findSourceOpsEsc="${findSourceOps//${TAB}/${TRIPLETT}}"
findSourceOpsEsc="${findSourceOpsEsc//${NLINE}/${TRIPLETN}}"

###########################################################

findGeneralOpsDefault=
findGeneralOpsDefault="${findGeneralOpsDefault}-ipath ${TRIPLETDSEP}\$RECYCLE.BIN -prune -o "
findGeneralOpsDefault="${findGeneralOpsDefault}-path ${TRIPLETDSEP}.Trash-[0-9]* -prune -o "
findGeneralOpsDefault="${findGeneralOpsDefault}-path ${TRIPLETDSEP}lost+found -prune -o "
if [ '+' == "${findGeneralOps:0:1}" ]; then
  findGeneralOps="${findGeneralOpsDefault} ${findGeneralOps:1}"
elif [ ${findGeneralOpsPassed} -eq 0 ]; then
  findGeneralOps="${findGeneralOpsDefault}"
fi
tmpVal="${findGeneralOps//${TRIPLETDSEP}/M}"
if [ "${tmpVal/${TRIPLET}/}" != "${tmpVal}" ]; then
  error_exit "<findGeneralOps> contains the directory separator triplet (${TRIPLET})"
fi
findGeneralOpsAwk="${findGeneralOps//${BSLASHPATTERN}/${TRIPLETB}}"
findGeneralOpsEsc="${findGeneralOps//${TAB}/${TRIPLETT}}"
findGeneralOpsEsc="${findGeneralOpsEsc//${NLINE}/${TRIPLETN}}"

###########################################################

metaDirDefault="${backupDir}${metaDirDefaultBase}"
if [ ${metaDirPassed} -eq 0 ]; then
  metaDir="${metaDirDefault}"
fi
if [ '' == "${metaDir}" ]; then
  error_exit '<metaDir> is mandatory if --metaDir option is given'
fi
if [ '/' != "${metaDir:0:1}" ] && [ './' != "${metaDir:0:2}" ]; then
  metaDir="./${metaDir}"
fi
if [ '/' != "${metaDir: -1:1}" ]; then
  metaDir="${metaDir}/"
fi
if [ "${metaDir/${TRIPLET}/}" != "${metaDir}" ]; then
  error_exit "<metaDir> contains the directory separator triplet (${TRIPLET})"
fi
metaDirAwk="${metaDir//${BSLASHPATTERN}/${TRIPLETB}}"
metaDirPattAwk="${metaDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
metaDirPattAwk="${metaDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
metaDirPattAwk="${metaDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
metaDirPattAwk="${metaDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
metaDirPattAwk="${metaDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
metaDirScp="${QUOTE}${metaDir//${QUOTEPATTERN}/${QUOTEESC}}${QUOTE}"
metaDirEsc="${metaDir//${TAB}/${TRIPLETT}}"
metaDirEsc="${metaDirEsc//${NLINE}/${TRIPLETN}}"

###########################################################

metaDirTempDefault="${sourceDir}${metaDirTempDefaultBase}"
if [ ${metaDirTempPassed} -eq 0 ]; then
  metaDirTemp="${metaDirTempDefault}"
fi
if [ '' == "${metaDirTemp}" ]; then
  error_exit '<metaDirTemp> is mandatory if --metaDirTemp option is given'
fi
if [ '/' != "${metaDirTemp:0:1}" ] && [ './' != "${metaDirTemp:0:2}" ]; then
  metaDirTemp="./${metaDirTemp}"
fi
if [ '/' != "${metaDirTemp: -1:1}" ]; then
  metaDirTemp="${metaDirTemp}/"
fi
if [ "${metaDirTemp/${TRIPLET}/}" != "${metaDirTemp}" ]; then
  error_exit "<metaDirTemp> contains the directory separator triplet (${TRIPLET})"
fi
metaDirTempAwk="${metaDirTemp//${BSLASHPATTERN}/${TRIPLETB}}"
metaDirTempScp="${QUOTE}${metaDirTemp//${QUOTEPATTERN}/${QUOTEESC}}${QUOTE}"
metaDirTempEsc="${metaDirTemp//${TAB}/${TRIPLETT}}"
metaDirTempEsc="${metaDirTempEsc//${NLINE}/${TRIPLETN}}"

###########################################################

findLastRunOpsFinalAwk="-path ${TRIPLETDSEP}${f999Base} -type f"
findSourceOpsFinalAwk="${findGeneralOpsAwk} ${findSourceOpsAwk}"
findBackupOpsFinalAwk="${findGeneralOpsAwk}"

if [ ${metaDirPassed} -eq 0 ]; then
  findSourceOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirDefaultBase} -prune -o ${findSourceOpsFinalAwk}"
  findBackupOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirDefaultBase} -prune -o ${findBackupOpsFinalAwk}"
fi

if [ ${remoteSource} -eq 1 ] || [ ${remoteBackup} -eq 1 ]; then
  if [ ${metaDirTempPassed} -eq 0 ]; then
    findSourceOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirTempDefaultBase} -prune -o ${findSourceOpsFinalAwk}"
    findBackupOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirTempDefaultBase} -prune -o ${findBackupOpsFinalAwk}"
  fi
fi

if [ ${remoteSource} -eq 1 ]; then
  metaDirLocal="${metaDir}"
  metaDirLocalAwk="${metaDirAwk}"
  metaDirSourceAwk="${metaDirTempAwk}"
elif [ ${remoteBackup} -eq 1 ]; then
  metaDirLocal="${metaDirTemp}"
  metaDirLocalAwk="${metaDirTempAwk}"
  metaDirSourceAwk="${metaDirTempAwk}"
else
  metaDirLocal="${metaDir}"
  metaDirLocalAwk="${metaDirAwk}"
  metaDirSourceAwk="${metaDirAwk}"
fi

###########################################################

if [ ${noDirChecks} -eq 0 ]; then
  if [ ${remoteSource} -eq 1 ]; then
    ssh ${sshOptions} "${sourceUserHost}" "[ -d ${sourceDirScp} ]" && tmpVal=$? || tmpVal=$?
    if [ ${tmpVal} -eq 1 ]; then
      error_exit '<sourceDir> is not a directory on the remote source host'
    elif [ ${tmpVal} -ne 0 ]; then
      error_exit 'SSH command failed'
    fi
  else
    if [ ! -d "${sourceDir}" ]; then
      error_exit '<sourceDir> is not a directory'
    fi
  fi
  if [ ${remoteBackup} -eq 1 ]; then
    ssh ${sshOptions} "${backupUserHost}" "[ -d ${backupDirScp} ]" && tmpVal=$? || tmpVal=$?
    if [ ${tmpVal} -eq 1 ]; then
      error_exit '<backupDir> is not a directory on the remote backup host'
    elif [ ${tmpVal} -ne 0 ]; then
      error_exit 'SSH command failed'
    fi
  else
    if [ ! -d "${backupDir}" ]; then
      error_exit '<backupDir> is not a directory'
    fi
  fi
fi

###########################################################

if [ ! -d "${metaDirLocal}" ]; then
  mkdir -p "${metaDirLocal}"
fi

f000="${metaDirLocal}${f000Base}"
f100="${metaDirLocal}${f100Base}"
f102="${metaDirLocal}${f102Base}"
f104="${metaDirLocal}${f104Base}"
f106="${metaDirLocal}${f106Base}"
f110="${metaDirLocal}${f110Base}"
f130="${metaDirLocal}${f130Base}"
f150="${metaDirLocal}${f150Base}"
f170="${metaDirLocal}${f170Base}"
f190="${metaDirLocal}${f190Base}"
f200="${metaDirLocal}${f200Base}"
f205="${metaDirLocal}${f205Base}"
f210="${metaDirLocal}${f210Base}"
f220="${metaDirLocal}${f220Base}"
f300="${metaDirLocal}${f300Base}"
f310="${metaDirLocal}${f310Base}"
f320="${metaDirLocal}${f320Base}"
f330="${metaDirLocal}${f330Base}"
f340="${metaDirLocal}${f340Base}"
f350="${metaDirLocal}${f350Base}"
f360="${metaDirLocal}${f360Base}"
f370="${metaDirLocal}${f370Base}"
f380="${metaDirLocal}${f380Base}"
f390="${metaDirLocal}${f390Base}"
f405="${metaDirLocal}${f405Base}"
f410="${metaDirLocal}${f410Base}"
f420="${metaDirLocal}${f420Base}"
f430="${metaDirLocal}${f430Base}"
f490="${metaDirLocal}${f490Base}"
f500="${metaDirLocal}${f500Base}"
f505="${metaDirLocal}${f505Base}"
f510="${metaDirLocal}${f510Base}"
f520="${metaDirLocal}${f520Base}"
f530="${metaDirLocal}${f530Base}"
f540="${metaDirLocal}${f540Base}"
f550="${metaDirLocal}${f550Base}"
f555="${metaDirLocal}${f555Base}"
f610="${metaDirLocal}${f610Base}"
f621="${metaDirLocal}${f621Base}"
f622="${metaDirLocal}${f622Base}"
f623="${metaDirLocal}${f623Base}"
f631="${metaDirLocal}${f631Base}"
f632="${metaDirLocal}${f632Base}"
f633="${metaDirLocal}${f633Base}"
f640="${metaDirLocal}${f640Base}"
f651="${metaDirLocal}${f651Base}"
f652="${metaDirLocal}${f652Base}"
f653="${metaDirLocal}${f653Base}"
f690="${metaDirLocal}${f690Base}"
f700="${metaDirLocal}${f700Base}"
f800="${metaDirLocal}${f800Base}"
f810="${metaDirLocal}${f810Base}"
f820="${metaDirLocal}${f820Base}"
f830="${metaDirLocal}${f830Base}"
f840="${metaDirLocal}${f840Base}"
f850="${metaDirLocal}${f850Base}"
f860="${metaDirLocal}${f860Base}"
f870="${metaDirLocal}${f870Base}"
f999="${metaDirLocal}${f999Base}"

f510Awk="${metaDirLocalAwk}${f510Base}"
f520Awk="${metaDirLocalAwk}${f520Base}"
f530Awk="${metaDirLocalAwk}${f530Base}"
f540Awk="${metaDirLocalAwk}${f540Base}"
f550Awk="${metaDirLocalAwk}${f550Base}"
f621Awk="${metaDirLocalAwk}${f621Base}"
f622Awk="${metaDirLocalAwk}${f622Base}"
f623Awk="${metaDirLocalAwk}${f623Base}"
f631Awk="${metaDirLocalAwk}${f631Base}"
f632Awk="${metaDirLocalAwk}${f632Base}"
f633Awk="${metaDirLocalAwk}${f633Base}"
f651Awk="${metaDirLocalAwk}${f651Base}"
f652Awk="${metaDirLocalAwk}${f652Base}"
f653Awk="${metaDirLocalAwk}${f653Base}"
f800Awk="${metaDirLocalAwk}${f800Base}"
f810Awk="${metaDirLocalAwk}${f810Base}"
f820Awk="${metaDirLocalAwk}${f820Base}"
f830Awk="${metaDirLocalAwk}${f830Base}"
f840Awk="${metaDirLocalAwk}${f840Base}"
f850Awk="${metaDirLocalAwk}${f850Base}"
f860Awk="${metaDirLocalAwk}${f860Base}"
f870Awk="${metaDirLocalAwk}${f870Base}"

# FILES IN TEMPORARY METADATA DIRECTORY OF ZALOHA ON REMOTE SOURCE HOST (IN REMOTE SOURCE MODE)
if [ ${remoteSource} -eq 1 ]; then
  ssh ${sshOptions} "${sourceUserHost}" "mkdir -p ${metaDirTempScp}"
fi

f205RemoteSourceScp="${metaDirTempScp}${f205Base}"
f210RemoteSourceScp="${metaDirTempScp}${f210Base}"
f310RemoteSourceScp="${metaDirTempScp}${f310Base}"
f631RemoteSourceScp="${metaDirTempScp}${f631Base}"
f633RemoteSourceScp="${metaDirTempScp}${f633Base}"

copyToRemoteSource=()
copyFromRemoteSource=
removeFromRemoteSource=

# FILES IN METADATA DIRECTORY OF ZALOHA ON REMOTE BACKUP HOST (IN REMOTE BACKUP MODE)
if [ ${remoteBackup} -eq 1 ]; then
  ssh ${sshOptions} "${backupUserHost}" "mkdir -p ${metaDirScp}"
fi

f000RemoteBackupScp="${metaDirScp}${f000Base}"
f100RemoteBackupScp="${metaDirScp}${f100Base}"
f200RemoteBackupScp="${metaDirScp}${f200Base}"
f205RemoteBackupScp="${metaDirScp}${f205Base}"
f220RemoteBackupScp="${metaDirScp}${f220Base}"
f300RemoteBackupScp="${metaDirScp}${f300Base}"
f320RemoteBackupScp="${metaDirScp}${f320Base}"
f505RemoteBackupScp="${metaDirScp}${f505Base}"
f610RemoteBackupScp="${metaDirScp}${f610Base}"
f621RemoteBackupScp="${metaDirScp}${f621Base}"
f623RemoteBackupScp="${metaDirScp}${f623Base}"
f640RemoteBackupScp="${metaDirScp}${f640Base}"
f651RemoteBackupScp="${metaDirScp}${f651Base}"
f653RemoteBackupScp="${metaDirScp}${f653Base}"
f690RemoteBackupScp="${metaDirScp}${f690Base}"
f700RemoteBackupScp="${metaDirScp}${f700Base}"
f800RemoteBackupScp="${metaDirScp}${f800Base}"
f810RemoteBackupScp="${metaDirScp}${f810Base}"
f820RemoteBackupScp="${metaDirScp}${f820Base}"
f830RemoteBackupScp="${metaDirScp}${f830Base}"
f840RemoteBackupScp="${metaDirScp}${f840Base}"
f850RemoteBackupScp="${metaDirScp}${f850Base}"
f860RemoteBackupScp="${metaDirScp}${f860Base}"
f870RemoteBackupScp="${metaDirScp}${f870Base}"
f999RemoteBackupScp="${metaDirScp}${f999Base}"

copyToRemoteBackup=()
copyFromRemoteBackup=
removeFromRemoteBackup=

# MAKE SURE THAT EVENTUAL OBSOLETE LOCAL-MODE SHELLSCRIPTS 620, 630 AND 650 FROM Zaloha.sh ARE REMOVED
files_not_prepared "${metaDirLocal}620_exec2.sh" "${metaDirLocal}630_exec3.sh" "${metaDirLocal}650_exec5.sh"

################ FLOWCHART STEP 1 #########################

${awk} '{ print }' << PARAMFILE > "${f000}"
${TRIPLET}${FSTAB}sourceDir${FSTAB}${sourceDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirAwk${FSTAB}${sourceDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirPattAwk${FSTAB}${sourceDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirScp${FSTAB}${sourceDirScp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirEsc${FSTAB}${sourceDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceUserHostDirTerm${FSTAB}${sourceUserHostDirTerm}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDir${FSTAB}${backupDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirAwk${FSTAB}${backupDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirPattAwk${FSTAB}${backupDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirScp${FSTAB}${backupDirScp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirEsc${FSTAB}${backupDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupUserHostDirTerm${FSTAB}${backupUserHostDirTerm}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceUserHost${FSTAB}${sourceUserHost}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceUserHostAwk${FSTAB}${sourceUserHostAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}remoteSource${FSTAB}${remoteSource}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupUserHost${FSTAB}${backupUserHost}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupUserHostAwk${FSTAB}${backupUserHostAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}remoteBackup${FSTAB}${remoteBackup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sshOptions${FSTAB}${sshOptions}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sshOptionsPassed${FSTAB}${sshOptionsPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}scpOptions${FSTAB}${scpOptions}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}scpOptionsPassed${FSTAB}${scpOptionsPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}scpExecOpt${FSTAB}${scpExecOpt}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}scpExecOptAwk${FSTAB}${scpExecOptAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}scpExecOptPassed${FSTAB}${scpExecOptPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOps${FSTAB}${findSourceOps}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsAwk${FSTAB}${findSourceOpsAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsEsc${FSTAB}${findSourceOpsEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOps${FSTAB}${findGeneralOps}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsAwk${FSTAB}${findGeneralOpsAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsEsc${FSTAB}${findGeneralOpsEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsPassed${FSTAB}${findGeneralOpsPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findParallel${FSTAB}${findParallel}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec${FSTAB}${noExec}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noRemove${FSTAB}${noRemove}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}revNew${FSTAB}${revNew}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}revUp${FSTAB}${revUp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}detectHLinksS${FSTAB}${detectHLinksS}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}ok2s${FSTAB}${ok2s}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}ok3600s${FSTAB}${ok3600s}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}byteByByte${FSTAB}${byteByByte}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sha256${FSTAB}${sha256}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noUnlink${FSTAB}${noUnlink}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}extraTouch${FSTAB}${extraTouch}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpOptions${FSTAB}${cpOptions}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpOptionsPassed${FSTAB}${cpOptionsPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpExecOpt${FSTAB}${cpExecOpt}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpExecOptAwk${FSTAB}${cpExecOptAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpRestoreOpt${FSTAB}${cpRestoreOpt}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpRestoreOptAwk${FSTAB}${cpRestoreOptAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}cpRestoreOptPassed${FSTAB}${cpRestoreOptPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pUser${FSTAB}${pUser}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pGroup${FSTAB}${pGroup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pMode${FSTAB}${pMode}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevUser${FSTAB}${pRevUser}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevGroup${FSTAB}${pRevGroup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevMode${FSTAB}${pRevMode}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}followSLinksS${FSTAB}${followSLinksS}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}followSLinksB${FSTAB}${followSLinksB}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}syncSLinks${FSTAB}${syncSLinks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noWarnSLinks${FSTAB}${noWarnSLinks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noRestore${FSTAB}${noRestore}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}optimCSV${FSTAB}${optimCSV}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDir${FSTAB}${metaDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirAwk${FSTAB}${metaDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirPattAwk${FSTAB}${metaDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirScp${FSTAB}${metaDirScp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirEsc${FSTAB}${metaDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirPassed${FSTAB}${metaDirPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirTemp${FSTAB}${metaDirTemp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirTempAwk${FSTAB}${metaDirTempAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirTempScp${FSTAB}${metaDirTempScp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirTempEsc${FSTAB}${metaDirTempEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirTempPassed${FSTAB}${metaDirTempPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noDirChecks${FSTAB}${noDirChecks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noLastRun${FSTAB}${noLastRun}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noIdentCheck${FSTAB}${noIdentCheck}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noFindSource${FSTAB}${noFindSource}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noFindBackup${FSTAB}${noFindBackup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no610Hdr${FSTAB}${no610Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no621Hdr${FSTAB}${no621Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no622Hdr${FSTAB}${no622Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no623Hdr${FSTAB}${no623Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no631Hdr${FSTAB}${no631Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no632Hdr${FSTAB}${no632Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no633Hdr${FSTAB}${no633Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no640Hdr${FSTAB}${no640Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no651Hdr${FSTAB}${no651Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no652Hdr${FSTAB}${no652Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}no653Hdr${FSTAB}${no653Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR800Hdr${FSTAB}${noR800Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR810Hdr${FSTAB}${noR810Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR820Hdr${FSTAB}${noR820Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR830Hdr${FSTAB}${noR830Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR840Hdr${FSTAB}${noR840Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR850Hdr${FSTAB}${noR850Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR860Hdr${FSTAB}${noR860Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR870Hdr${FSTAB}${noR870Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noProgress${FSTAB}${noProgress}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}color${FSTAB}${color}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}mawk${FSTAB}${mawk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}lTest${FSTAB}${lTest}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findLastRunOpsFinalAwk${FSTAB}${findLastRunOpsFinalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsFinalAwk${FSTAB}${findSourceOpsFinalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findBackupOpsFinalAwk${FSTAB}${findBackupOpsFinalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirLocal${FSTAB}${metaDirLocal}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirLocalAwk${FSTAB}${metaDirLocalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirSourceAwk${FSTAB}${metaDirSourceAwk}${FSTAB}${TRIPLET}
PARAMFILE

copyToRemoteBackup+=( "${f000}" )

################ FLOWCHART STEPS 2 - 4 ####################

${awk} '{ print }' << 'AWKAWKPREPROC' > "${f100}"
BEGIN {
  eex = "BEGIN {\n"                                                         \
        "  error_exit_filename = \"\"\n"                                    \
        "}\n"                                                               \
        "function error_exit( msg ) {\n"                                    \
        "  if ( \"\" == error_exit_filename ) {\n"                          \
        "    if ( \"\" != FILENAME ) {\n"                                   \
        "      error_exit_filename = FILENAME\n"                            \
        "      sub( /^.*\\//, \"\", error_exit_filename )\n"                \
        "      msg = \"(\" error_exit_filename \" FNR:\" FNR \") \" msg\n"  \
        "    }\n"                                                           \
        "    gsub( CNTRLREGEX, TRIPLETC, msg )\n"                           \
        "    print \"\\nZaloha AWK: \" msg > \"/dev/stderr\"\n"             \
        "    exit 1\n"                                                      \
        "  }\n"                                                             \
        "}"
  war = "function warning( msg ) {\n"                                       \
        "  if ( \"\" == error_exit_filename ) {\n"                          \
        "    gsub( CNTRLREGEX, TRIPLETC, msg )\n"                           \
        "    print \"\\nZaloha AWK: Warning: \" msg > \"/dev/stderr\"\n"    \
        "  }\n"                                                             \
        "}"
  mpa = 8     # MAXPARALLEL constant
}
{
  gsub( /DEFINE_ERROR_EXIT/, eex )
  gsub( /DEFINE_WARNING/, war )
  gsub( /BIN_BASH/, "print \"#!/bin/bash\"" )
  gsub( /XTRACE_ON_CP/, "print \"BASH_XTRACEFD=3; PS4='    '; set -x\"" )
  gsub( /XTRACE_ON/, "print \"BASH_XTRACEFD=1; PS4='    '; set -x\"" )
  gsub( /XTRACE_OFF/, "print \"  { set +x; } > /dev/null\"" )
  gsub( /SECTION_LINE/, "print \"#\" FSTAB TRIPLET" )
  gsub( /TABREGEX/, "/\\t/" )
  gsub( /FSTAB/, "\"\\t\"" )
  gsub( /TAB/, "\"\\t\"" )
  gsub( /NLINE/, "\"\\n\"" )
  gsub( /BSLASH/, "\"BSLASH\\\"" )
  gsub( /BSLASH/, "\\" )
  gsub( /SLASHREGEX/, "/\\//" )
  gsub( /SLASH/, "\"/\"" )
  gsub( /DQUOTE/, "\"\\\"\"" )
  gsub( /TRIPLETDSEPREGEX/, "/\\/\\/\\/d\\//" )
  gsub( /TRIPLETTREGEX/, "/\\/\\/\\/t/" )
  gsub( /TRIPLETNREGEX/, "/\\/\\/\\/n/" )
  gsub( /TRIPLETBREGEX/, "/\\/\\/\\/b/" )
  gsub( /TRIPLETSREGEX/, "/\\/\\/\\/s/" )
  gsub( /TRIPLETDSEP/, "\"///d/\"" )
  gsub( /TRIPLETT/, "\"///t\"" )
  gsub( /TRIPLETN/, "\"///n\"" )
  gsub( /TRIPLETC/, "\"///c\"" )
  gsub( /TRIPLETSLENGTH/, "4" )
  gsub( /TRIPLETS/, "\"///s\"" )
  gsub( /TRIPLET/, "\"///\"" )
  gsub( /QUOTEREGEX/, "/'/" )
  gsub( /QUOTEESCSCP/, "\"\\\"'\\\"'\\\"'\\\"'\\\"'\\\"'\\\"'\\\"\"" )
  gsub( /QUOTEESC/, "\"'\\\"'\\\"'\"" )
  gsub( /QUOTESCP/, "\"\\\"'\\\"\"" )
  gsub( /ALPHAREGEX/, "/[a-zA-Z]/" )
  gsub( /SIGNNUMBERREGEX/, "/^[+-]?[0123456789]+$/" )
  gsub( /NUMBERREGEX/, "/^[0123456789]+$/" )
  gsub( /SHA256REGEX/, "/^[0123456789abcdef]{64}$/" )
  gsub( /ZEROREGEX/, "/^0+$/" )
  gsub( /CNTRLREGEX/, "/[[:cntrl:]]/" )
  gsub( /FATREGEX/, "/[Ff][Aa][Tt]/" )
  gsub( /TERMNORM/, "\"\\033[0m\"" )
  gsub( /TERMRED/, "\"\\033[91m\"" )
  gsub( /TERMBLUE/, "\"\\033[94m\"" )
  if ( $0 ~ /ONE_TO_MAXPARALLEL/ ) {
    for ( i = 1; i <= mpa; i ++ ) {
      s = $0
      gsub( /ONE_TO_MAXPARALLEL/, i, s )
      gsub( /MAXPARALLEL/, mpa, s )
      print s
    }
  } else {
    gsub( /MAXPARALLEL/, mpa )
    print
  }
}
AWKAWKPREPROC

copyToRemoteBackup+=( "${f100}" )

${awk} -f "${f100}" << 'AWKXTRACE2TERM' > "${f102}"
{
  if ( 1 == color ) {
    gsub( TABREGEX, TRIPLETT )
    gsub( CNTRLREGEX, TERMBLUE TRIPLETC TERMNORM )
    gsub( TRIPLETTREGEX, TERMBLUE TRIPLETT TERMNORM )
  } else {
    gsub( TABREGEX, TRIPLETT )
    gsub( CNTRLREGEX, TRIPLETC )
  }
  print
}
AWKXTRACE2TERM

${awk} -f "${f100}" << 'AWKACTIONS2TERM' > "${f104}"
BEGIN {
  FS = FSTAB
}
{
  pt = $14
  if ( 1 == color ) {
    gsub( CNTRLREGEX, TERMBLUE TRIPLETC TERMNORM, pt )
    gsub( TRIPLETNREGEX, TERMBLUE TRIPLETN TERMNORM, pt )
    gsub( TRIPLETTREGEX, TERMBLUE TRIPLETT TERMNORM, pt )
    if ( $2 ~ /^(REMOVE|UPDATE|unl\.UP|SLINK\.u|REV\.UP)/ ) {    # actions requiring more attention
      printf "%s%-10s%s%s\n", TERMRED, $2, TERMNORM, pt
    } else {
      printf "%-10s%s\n", $2, pt
    }
  } else {
    gsub( CNTRLREGEX, TRIPLETC, pt )
    printf "%-10s%s\n", $2, pt
  }
}
AWKACTIONS2TERM

################ FLOWCHART STEPS 5 - 11 ###################

${awk} -f "${f100}" << 'AWKPARSER' > "${f106}"
DEFINE_ERROR_EXIT
BEGIN {
  gsub( TRIPLETBREGEX, BSLASH, startPoint )
  gsub( TRIPLETBREGEX, BSLASH, findOps )
  gsub( TRIPLETBREGEX, BSLASH, tripletDSepV )
  gsub( TRIPLETBREGEX, BSLASH, metaDir )
  gsub( QUOTEREGEX, QUOTEESC, startPoint )
  gsub( QUOTEREGEX, QUOTEESC, metaDir )
  cmd = "exec find"              # FIND command being constructed
  wrd = ""                       # word of FIND command being constructed
  iwd = 0                        # flag inside of word (0=before, 1=in, 2=after)
  idq = 0                        # flag inside of double-quote
  dqu = 0                        # flag double-quote remembered
  if ( 1 == followSLinks ) {
    cmd = cmd " -L"
  }
  cmd = cmd " '" startPoint "'"
  findOps = findOps " "
  for ( i = 1; i <= length( findOps ); i ++ ) {
    c = substr( findOps, i, 1 )
    if ( 1 == dqu ) {
      dqu = 0
      if ( DQUOTE == c ) {
        wrd = wrd c
        continue
      } else {
        idq = 0
      }
    }
    if ( DQUOTE == c ) {
      if ( 1 == idq ) {
        dqu = 1
      } else {
        iwd = 1
        idq = 1
      }
    } else if ( " " == c ) {
      if ( 1 == idq ) {
        wrd = wrd c
      } else if ( 1 == iwd ) {
        iwd = 2
      }
    } else {
      wrd = wrd c
      iwd = 1
    }
    # word boundary found: post-process word and add it to command
    if ( 2 == iwd ) {
      n = split( wrd, a, TRIPLETDSEPREGEX )
      if ( 2 < n ) {
        error_exit( "<findOps> contains more than one placeholder " TRIPLETDSEP " in one word" )
      } else if ( 2 == n ) {
        wrd = a[1] tripletDSepV a[2]
      }
      gsub( QUOTEREGEX, QUOTEESC, wrd )
      cmd = cmd " '" wrd "'"
      wrd = ""
      iwd = 0
    }
  }
  if ( 1 == idq ) {
    error_exit( "<findOps> contains unpaired double quote" )
  }
  if ( 1 == sha256 ) {
    cmd = cmd " '(' -type f -printf '"
    cmd = cmd TRIPLET                                    # SHA-256 column 1: leading field
    cmd = cmd "\\tSHA-256"                               # SHA-256 column 2: SHA-256 constant
    cmd = cmd "\\t' '(' -exec sha256sum '{}' ';'"        # SHA-256 column 3: the SHA-256 hash + space + file name + newline
    cmd = cmd " -printf '\\t" TRIPLET "' -o -true ')'"   # SHA-256 column 4: terminator field
    cmd = cmd " -printf '\\n' -false ')' -o"
  }
  if ( 1 == readSLinks ) {
    cmd = cmd " '(' -lname '*" TRIPLET "*' -printf '"
    cmd = cmd TRIPLET                                                 # SLINK-TARGET column 1: leading field
    cmd = cmd "\\tSLINK-TARGET"                                       # SLINK-TARGET column 2: SLINK-TARGET constant
    cmd = cmd "\\t' '(' -exec bash '" metaDir f205Base "' '{}' ';'"   # SLINK-TARGET column 3: escaped target path of symbolic link
    cmd = cmd " -printf '\\t" TRIPLET "' -o -true ')'"                # SLINK-TARGET column 4: terminator field
    cmd = cmd " -printf '\\n' -false ')' -o"
  }
  cmd = cmd " -printf '"
  cmd = cmd TRIPLET                  # column  1: leading field
  cmd = cmd "\\t" sourceBackup       # column  2: S = <sourceDir>, B = <backupDir>, L = last run record
  cmd = cmd "\\t%y"                  # column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
  cmd = cmd "\\t%s"                  # column  4: file's size in bytes
  cmd = cmd "\\t%Ts"                 # column  5: file's last modification time, seconds since 01/01/1970
  cmd = cmd "\\t%F"                  # column  6: type of the filesystem the file is on
  cmd = cmd "\\t%D"                  # column  7: device number the file is on
  cmd = cmd "\\t%i"                  # column  8: file's inode number
  cmd = cmd "\\t%n"                  # column  9: number of hardlinks to file
  cmd = cmd "\\t%u"                  # column 10: file's user name
  cmd = cmd "\\t%g"                  # column 11: file's group name
  cmd = cmd "\\t%m"                  # column 12: file's permission bits (in octal)
  cmd = cmd "\\t0"                   # column 13: SHA-256 hash of file's contents (if --sha256 option is given)
  cmd = cmd "\\t%P"                  # column 14: file's path with <sourceDir> or <backupDir> stripped
  cmd = cmd "\\t" TRIPLET "'"        # column 15: terminator field
  cmd = cmd " '(' -lname '*" TRIPLET "*' -printf '\\t' -o -printf '\\t%l' ')'"  # column 16: target path of symbolic link
  cmd = cmd " -printf '\\t" TRIPLET  # column 17: terminator field
  cmd = cmd "\\n' > '" metaDir fOutBase "'"
  BIN_BASH
  print "set -e"
  if ( 0 == noProgress ) {
    XTRACE_ON
  }
  print cmd
}
AWKPARSER

${awk} '{ print }' << 'READSLINK' > "${f205}"
#!/bin/bash
set -u
set -e
TAB=$'\t'
NLINE=$'\n'
SLASH='/'
TRIPLETT='///t'
TRIPLETN='///n'
TRIPLETS='///s'
tmpVal="$(readlink -n "${1}" && printf 'M')"
tmpVal="${tmpVal%'M'}"
tmpVal="${tmpVal//${SLASH}/${TRIPLETS}}"
tmpVal="${tmpVal//${TAB}/${TRIPLETT}}"
printf '%s' "${tmpVal//${NLINE}/${TRIPLETN}}"
# end
READSLINK

if [ ${noProgress} -eq 0 ]; then

  printf '\nANALYZING %s AND %s\n' "${sourceUserHostDirTerm}" "${backupUserHostDirTerm}"
  printf '===========================================\n'

fi

start_progress 'Parsing'

${awk} -f "${f106}"                            \
       -v sourceBackup='L'                     \
       -v startPoint="${metaDirAwk}"           \
       -v followSLinks=0                       \
       -v findOps="${findLastRunOpsFinalAwk}"  \
       -v tripletDSepV="${metaDirPattAwk}"     \
       -v sha256=0                             \
       -v readSLinks=0                         \
       -v metaDir="${metaDirAwk}"              \
       -v f205Base="${f205Base}"               \
       -v fOutBase="${f300Base}"               \
       -v noProgress=${noProgress}             > "${f200}"

copyToRemoteBackup+=( "${f200}" )

${awk} -f "${f106}"                            \
       -v sourceBackup='S'                     \
       -v startPoint="${sourceDirAwk}"         \
       -v followSLinks=${followSLinksS}        \
       -v findOps="${findSourceOpsFinalAwk}"   \
       -v tripletDSepV="${sourceDirPattAwk}"   \
       -v sha256=${sha256}                     \
       -v readSLinks=1                         \
       -v metaDir="${metaDirSourceAwk}"        \
       -v f205Base="${f205Base}"               \
       -v fOutBase="${f310Base}"               \
       -v noProgress=${noProgress}             > "${f210}"

copyToRemoteSource+=( "${f205}" "${f210}" )

${awk} -f "${f106}"                            \
       -v sourceBackup='B'                     \
       -v startPoint="${backupDirAwk}"         \
       -v followSLinks=${followSLinksB}        \
       -v findOps="${findBackupOpsFinalAwk}"   \
       -v tripletDSepV="${backupDirPattAwk}"   \
       -v sha256=${sha256}                     \
       -v readSLinks=1                         \
       -v metaDir="${metaDirAwk}"              \
       -v f205Base="${f205Base}"               \
       -v fOutBase="${f320Base}"               \
       -v noProgress=${noProgress}             > "${f220}"

copyToRemoteBackup+=( "${f205}" "${f220}" )

stop_progress

# Copy the prepared FIND shellscripts and other metadata to the remote side

if [ ${remoteSource} -eq 1 ]; then

  progress_scp_meta '>'

  scp ${scpMetaOpt} "${copyToRemoteSource[@]}" "${sourceUserHost}:${metaDirTempScp}"

  progress_scp_meta '>'

  copyToRemoteSource=()

elif [ ${remoteBackup} -eq 1 ]; then

  progress_scp_meta '>'

  scp ${scpMetaOpt} "${copyToRemoteBackup[@]}" "${backupUserHost}:${metaDirScp}"

  progress_scp_meta '>'

  copyToRemoteBackup=()

fi

# FIND scan of the 999 file to obtain time of last run of Zaloha

if [ ${noLastRun} -eq 0 ]; then

  if [ ${remoteBackup} -eq 1 ]; then

    ssh ${sshOptions} "${backupUserHost}" "bash ${f200RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}

    copyFromRemoteBackup+="${f300RemoteBackupScp} "

  else

    bash "${f200}" | ${awkNoBuf} -f "${f102}" -v color=${color}

  fi

  fLastRun="${f300}"

else

  files_not_prepared "${f300}"

  removeFromRemoteBackup+="${f300RemoteBackupScp} "

  fLastRun='/dev/null'

fi

# In case of --findParallel, run the local scan now as background job.
# Use "set -m" to place the background job in own process group.

if [ ${findParallel} -eq 1 ]; then

  if [ ${remoteSource} -eq 1 ]; then

    set -m
    ( bash "${f220}" | ${awkNoBuf} -f "${f102}" -v color=${color} ) &
    pidBackgroundJob=$!
    set +m

  else

    set -m
    ( bash "${f210}" | ${awkNoBuf} -f "${f102}" -v color=${color} ) &
    pidBackgroundJob=$!
    set +m

  fi

fi

# FIND scan of <sourceDir>

if [ ${noFindSource} -eq 0 ]; then

  if [ ${remoteSource} -eq 1 ]; then

    ssh ${sshOptions} "${sourceUserHost}" "bash ${f210RemoteSourceScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}

    copyFromRemoteSource+="${f310RemoteSourceScp} "

  elif [ ${findParallel} -eq 0 ]; then

    bash "${f210}" | ${awkNoBuf} -f "${f102}" -v color=${color}

  fi

else

  if [ ! -f "${f310}" ]; then
    error_exit 'The externally supplied CSV metadata file 310 does not exist'
  fi

  if [ ! "${f310}" -nt "${f999}" ]; then
    error_exit 'The externally supplied CSV metadata file 310 is not newer than the last run of Zaloha'
  fi

fi

# FIND scan of <backupDir>

if [ ${noFindBackup} -eq 0 ]; then

  if [ ${remoteBackup} -eq 1 ]; then

    ssh ${sshOptions} "${backupUserHost}" "bash ${f220RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}

    copyFromRemoteBackup+="${f320RemoteBackupScp} "

  elif [ ${findParallel} -eq 0 ]; then

    bash "${f220}" | ${awkNoBuf} -f "${f102}" -v color=${color}

  fi

else

  if [ ! -f "${f320}" ]; then
    error_exit 'The externally supplied CSV metadata file 320 does not exist'
  fi

  if [ ! "${f320}" -nt "${f999}" ]; then
    error_exit 'The externally supplied CSV metadata file 320 is not newer than the last run of Zaloha'
  fi

fi

# Copy the obtained CSV metadata back from the remote side

if [ '' != "${copyFromRemoteSource}" ]; then

  progress_scp_meta '<'

  scp ${scpMetaOpt} "${sourceUserHost}:${copyFromRemoteSource}" "${metaDirLocal}"

  progress_scp_meta '<'

elif [ '' != "${copyFromRemoteBackup}" ]; then

  progress_scp_meta '<'

  scp ${scpMetaOpt} "${backupUserHost}:${copyFromRemoteBackup}" "${metaDirLocal}"

  progress_scp_meta '<'

fi

# In case of --findParallel, wait for the background job to finish

if [ ${findParallel} -eq 1 ]; then

  wait ${pidBackgroundJob} && tmpVal=$? || tmpVal=$?

  pidBackgroundJob=

  if [ ${tmpVal} -ne 0 ]; then
    error_exit "The local FIND scan terminated with unexpected exit status ${tmpVal}"
  fi

fi

################ FLOWCHART STEPS 12 - 14 ##################

${awk} -f "${f100}" << 'AWKCLEANER' > "${f110}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB   # FSTAB or TAB, because fields are separated both by tabs produced by FIND as well as by tabs contained in filenames
  OFS = FSTAB
  spr = 0      # flag remainder of SHA-256 record in progress
  sha = ""     # SHA-256 hash from the SHA-256 record
  tsl = ""     # target path of symbolic link from the SLINK-TARGET record
  fin = 1      # field index in output record
  fpr = 0      # flag field in progress (for fin 14 or 16)
  fne = 0      # flag field not empty
  rec = ""     # output record
}
function add_fragment_to_field( fragment, verbatim ) {
  if ( "" != fragment ) {
    fne = 1
  }
  if ((( 14 == fin ) || ( 16 == fin )) && ( 0 == verbatim )) {                #  (in fields 14 and 16, convert slashes to TRIPLETSs)
    gsub( SLASHREGEX, TRIPLETS, fragment )
  }
  rec = rec fragment
}
{
  #### remainder of SHA-256 record in progress
  if ( 1 == spr ) {
    if ( TRIPLET == $1 ) {
      error_exit( "AWK cleaner in unexpected state at begin of new record (2): presumably sha256sum has failed" )
    } else if ( TRIPLET == $NF ) {
      spr = 0
    }
  #### the SHA-256 record itself
  } else if (( 1 == fin ) && ( TRIPLET == $1 ) && ( "SHA-256" == $2 )) {
    if ( "" != sha ) {
      error_exit( "Unprocessed SHA-256 hash while a new SHA-256 record encountered" )
    }
    if ( "" != tsl ) {
      error_exit( "Unprocessed target path of symbolic link while an SHA-256 record encountered" )
    }
    if ( BSLASH == substr( $3, 1, 1 )) {
      sha = substr( $3, 2, 64 )
    } else {
      sha = substr( $3, 1, 64 )
    }
    if ( TRIPLET != $NF ) {
      spr = 1
    }
  #### the SLINK-TARGET record
  } else if (( 1 == fin ) && ( TRIPLET == $1 ) && ( "SLINK-TARGET" == $2 )) {
    if ( "" != sha ) {
      error_exit( "Unprocessed SHA-256 hash while an SLINK-TARGET record encountered" )
    }
    if ( "" != tsl ) {
      error_exit( "Unprocessed target path of symbolic link while a new SLINK-TARGET record encountered" )
    }
    if (( 4 != NF ) || ( TRIPLET != $NF )) {
      error_exit( "Unexpected structure of SLINK-TARGET record: presumably read of symbolic link has failed" )
    }
    tsl = $3
  #### regular record: the unproblematic case performance-optimized
  } else if (( 1 == fin ) && ( 17 == NF ) && ( TRIPLET == $1 ) && ( TRIPLET == $17 )) {
    if ( "" != sha ) {
      $13 = sha
      sha = ""
    }
    if ( "" != $14 ) {
      $14 = $14 SLASH                                   #  (if field 14 is not empty, append slash and convert slashes to TRIPLETSs)
      gsub( SLASHREGEX, TRIPLETS, $14 )
    }
    if ( "" != tsl ) {
      if ( "" != $16 ) {
        error_exit( "Unexpected, unprocessed SLINK-TARGET record and column 16 not empty (1)" )
      }
      $16 = tsl
      tsl = ""
    } else {
      gsub( SLASHREGEX, TRIPLETS, $16 )
    }
    print
  #### regular record: full processing otherwise
  } else {
    if ( 0 == NF ) {                                    ### blank input line
      if ( 1 == fpr ) {                                 ## blank input line while fin 14 or 16 in progress (= newline in file name)
        add_fragment_to_field( TRIPLETN, 1 )
      } else {                                          ## blank input line otherwise
        error_exit( "Unexpected blank line in raw output of FIND" )
      }
    } else {                                            ### non-blank input line
      if (( TRIPLET == $1 ) && (( 1 != fin ) || ( 0 != fpr ))) {
        error_exit( "AWK cleaner in unexpected state at begin of new record (1)" )
      }
      for ( i = 1; i <= NF; i ++ ) {
        if ( 1 == fpr ) {                               ## fin 14 or 16 in progress
          if ( TRIPLET == $i ) {                        # TRIPLET terminator found
            if (( 14 == fin ) && ( 1 == fne )) {        #  (append TRIPLETS to field 14 (if field 14 is not empty))
              add_fragment_to_field( TRIPLETS, 1 )
            } else if (( 16 == fin ) && ( "" != tsl )) {
              if ( 1 == fne ) {
                error_exit( "Unexpected, unprocessed SLINK-TARGET record and column 16 not empty (2)" )
              }
              add_fragment_to_field( tsl, 1 )
              tsl = ""
            }
            rec = rec FSTAB TRIPLET
            fin += 2
            fpr = 0
            fne = 0
          } else if ( 1 == i ) {                        # fin 14 or 16 in progress continues on next line (= newline in file name)
            add_fragment_to_field( TRIPLETN, 1 )
            add_fragment_to_field( $i, 0 )
          } else {                                      # fin 14 or 16 in progress continues in next field (= tab in file name)
            add_fragment_to_field( TRIPLETT, 1 )
            add_fragment_to_field( $i, 0 )
          }
        } else {                                        ## normal case (= fin 14 or 16 not in progress)
          if ( 1 == fin ) {                             # field 1 starts a record
            add_fragment_to_field( $i, 0 )
            fin = 2
            fne = 0
          } else if (( 14 == fin ) || ( 16 == fin )) {  # fields 14 and 16 are terminator-delimited: start progress
            rec = rec FSTAB
            add_fragment_to_field( $i, 0 )
            fpr = 1
          } else {                                      # other fields are regular
            rec = rec FSTAB
            if (( 13 == fin ) && ( "" != sha )) {
              add_fragment_to_field( sha, 1 )
              sha = ""
            } else {
              add_fragment_to_field( $i, 0 )
            }
            fin ++
            fne = 0
          }
        }
      }
      if (( TRIPLET == $NF ) && (( 18 != fin ) || ( 0 != fpr ))) {
        error_exit( "AWK cleaner in unexpected state at end of record" )
      }
      if ( 18 < fin ) {
        error_exit( "AWK cleaner in unexpected state at end of input line" )
      }
    }
    if ( 18 == fin ) {                                  ### output record is complete (18 = index of last field + 1)
      print rec
      rec = ""
      fin = 1
    }
  }
}
END {
  if (( 0 != spr ) || ( "" != sha )) {
    error_exit( "AWK cleaner in unexpected state at end of file (1)" )
  }
  if ( "" != tsl ) {
    error_exit( "AWK cleaner in unexpected state at end of file (2)" )
  }
  if (( 1 != fin ) || ( 0 != fpr )) {
    error_exit( "AWK cleaner in unexpected state at end of file (3)" )
  }
}
AWKCLEANER

start_progress 'Cleaning'

${awk} -f "${f110}" "${f310}" > "${f330}"

optim_csv_after_use "${f310}"

${awk} -f "${f110}" "${f320}" > "${f340}"

optim_csv_after_use "${f320}"

stop_progress

################ FLOWCHART STEPS 15 - 18 ##################

${awk} -f "${f100}" << 'AWKCHECKER' > "${f130}"
DEFINE_ERROR_EXIT
DEFINE_WARNING
BEGIN {
  FS = FSTAB
  cfd = 0       # count of files on given device
  cfc = 0       # count of files on given device with correct modification times
  csd = 0       # count of symbolic links on given device
  csc = 0       # count of symbolic links on given device with non-empty target paths
  tp = "d"
  dv = ""
  pp = "M" TRIPLETS
}
function mtimes_check() {
  if (( 0 != cfd ) && ( 0 == cfc )) {
    warning( "All " cfd " files on device " dv " have zero (or negative) modification times" )
  }
}
function target_paths_check() {
  if (( 0 != csd ) && ( 0 == csc )) {
    warning( "All " csd " symbolic links on device " dv " have empty target paths" )
  }
}
{
  # switch to a new device: perform per-device checks
  if ( dv != $7 ) {
    mtimes_check()
    cfd = 0
    cfc = 0
    target_paths_check()
    csd = 0
    csc = 0
  }
  if ( 17 != NF ) {
    error_exit( "Unexpected, cleaned CSV file does not contain 17 columns" )
  }
  if ( $1 != TRIPLET ) {
    error_exit( "Unexpected, column 1 of cleaned file is not the leading field" )
  }
  if ( $2 !~ /[LSB]/ ) {
    error_exit( "Unexpected, column 2 of cleaned file (Source/Backup indicator) contains invalid value" )
  }
  if ( $3 !~ /[dflpscbD]/ ) {
    error_exit( "Unexpected, column 3 of cleaned file (file's type) contains invalid value" )
  }
  if ( $4 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 4 of cleaned file (file's size in bytes) is not numeric" )
  }
  if ( $5 !~ SIGNNUMBERREGEX ) {
    error_exit( "Unexpected, column 5 of cleaned file (file's last modification time) is not numeric" )
  }
  if ( "f" == $3 ) {
    cfd ++
    if ( $5 > 0 ) {      # correct (expected) modification time is a positive integer
      cfc ++
    }
  }
  if ( $6 !~ ALPHAREGEX ) {
    error_exit( "Unexpected, column 6 of cleaned file (type of the filesystem) is not alphanumeric" )
  }
  if ( $7 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 7 of cleaned file (device number) is not numeric" )
  }
  if ( $8 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 8 of cleaned file (file's inode number) is not numeric" )
  }
  if ( $9 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 9 of cleaned file (number of hardlinks to file) is not numeric" )
  }
  if ( $9 ~ ZEROREGEX ) {
    error_exit( "Unexpected, column 9 of cleaned file (number of hardlinks to file) is zero" )
  }
  if ( $10 == "" ) {
    error_exit( "Unexpected, column 10 of cleaned file (file's user name) is empty" )
  }
  if ( $11 == "" ) {
    error_exit( "Unexpected, column 11 of cleaned file (file's group name) is empty" )
  }
  if ( $12 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 12 of cleaned file (file's permission bits) is not numeric" )
  }
  if (( 1 == sha256 ) && ( "f" == $3 )) {
    if ( $13 !~ SHA256REGEX ) {
      error_exit( "Unexpected, column 13 of cleaned file does not contain a SHA-256 hash" )
    }
  } else {
    if ( "0" != $13 ) {
      error_exit( "Unexpected, column 13 of cleaned file does not contain the 0 constant" )
    }
  }
  if ( $14 == "" ) {
    if ( 1 != NR ) {
      error_exit( "Unexpected, column 14 of cleaned file (file's path) is empty for other than first record" )
    }
    if ( "d" != $3 ) {
      error_exit( "Unexpected, column 14 of cleaned file (file's path) is empty for other first record than a directory" )
    }
  }
  if ( $15 != TRIPLET ) {
    error_exit( "Unexpected, column 15 of cleaned file is not the terminator field" )
  }
  if ( "l" == $3 ) {
    csd ++
    if ( $16 != "" ) {   # correct (expected) target path of a symbolic link is a non-empty string
      csc ++
    }
  } else {
    if ( $16 != "" ) {
      error_exit( "Unexpected, column 16 of cleaned file (target path of symbolic link) is not empty for other object than symbolic link" )
    }
  }
  if ( $17 != TRIPLET ) {
    error_exit( "Unexpected, column 17 of cleaned file is not the terminator field" )
  }
  # this directories hierarchy check might reveal some <findSourceOps> and/or <findGeneralOps> errors,
  # e.g. subdirectory excluded but its contents not excluded
  if ( 1 == checkDirs ) {
    p = "M" TRIPLETS "M" TRIPLETS $14
    n = split( p, a, TRIPLETSREGEX )
    if ( "" != a[n] ) {
      error_exit( "Unexpected, column 14 of cleaned file (file's path) ends incorrectly" )
    }
    t = substr( p, 1, length( p ) - TRIPLETSLENGTH - length( a[n-1] ))
    if ( pp == t ) {
      if ( "d" != tp ) {
        gsub( TRIPLETSREGEX, SLASH, p )
        p = substr( p, 5, length( p ) - 5 )
        error_exit( "Unexpected: Parent of this object is not a directory: " p )
      }
    } else if ( 1 != index( pp, t )) {
      gsub( TRIPLETSREGEX, SLASH, p )
      p = substr( p, 5, length( p ) - 5 )
      error_exit( "Unexpected: Parent directory record missing before: " p )
    }
    tp = $3   # previous record's column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
    pp = p    # previous record's column 14: file's path with <sourceDir> or <backupDir> stripped + prefix added
  }
  dv = $7     # previous record's column  7: device number the file is on
}
END {
  if (( 1 == checkDirs ) && ( 0 == NR )) {
    error_exit( "Unexpected, no records in file (at least the start point directory should be there)" )
  }
  mtimes_check()
  target_paths_check()
}
AWKCHECKER

start_progress 'Checking'

if [ ${noLastRun} -eq 0 ]; then
  ${awk} -f "${f130}" -v checkDirs=0 -v sha256=0 "${fLastRun}"
fi

${awk} -f "${f130}" -v checkDirs=1 -v sha256=${sha256} "${f330}"

${awk} -f "${f130}" -v checkDirs=1 -v sha256=${sha256} "${f340}"

stop_progress

################ FLOWCHART STEPS 19 - 21 ##################

${awk} -f "${f100}" << 'AWKHLINKS' > "${f150}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  tp = ""
}
{
  # hardlink detection only for files
  # device and inode numbers prepended by "M" to enforce string comparisons (numbers could overflow)
  if ( ( "f" == tp ) && ( "f" == $3 )                     \
    && ( $7 !~ ZEROREGEX ) && (( "M" dv ) == ( "M" $7 ))  \
    && ( $8 !~ ZEROREGEX ) && (( "M" id ) == ( "M" $8 ))  \
  ) {
    hcn ++
    if ( $9 < hcn ) {
      error_exit( "Unexpected, detected hardlink count is higher than number of hardlinks to file" )
    }
    if (( "M" sz ) != ( "M" $4 )) {
      error_exit( "Unexpected falsely detected hardlink (size differs)" )
    }
    if (( "M" tm ) != ( "M" $5 )) {
      error_exit( "Unexpected falsely detected hardlink (modification time differs)" )
    }
    if ( nh != $9 ) {
      error_exit( "Unexpected falsely detected hardlink (number of hardlinks differs)" )
    }
    if ( us != $10 ) {
      error_exit( "Unexpected falsely detected hardlink (user name differs)" )
    }
    if ( gr != $11 ) {
      error_exit( "Unexpected falsely detected hardlink (group name differs)" )
    }
    if ( md != $12 ) {
      error_exit( "Unexpected falsely detected hardlink (mode differs)" )
    }
    if ( ha != $13 ) {
      error_exit( "Unexpected falsely detected hardlink (SHA-256 hash differs)" )
    }
    $3 = "h"    # file's type is set to hardlink
    $16 = pt    # path of first link (the "file") goes into column 16
    if ( "" != $16 ) {
      gsub( TRIPLETSREGEX, SLASH, $16 )
      $16 = substr( $16, 1, length( $16 ) - 1 )
    }
  } else {
    hcn = 1     # detected hardlink count
    tp = $3     # previous record's column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
    sz = $4     # previous record's column  4: file's size in bytes
    tm = $5     # previous record's column  5: file's last modification time, seconds since 01/01/1970
    dv = $7     # previous record's column  7: device number the file is on
    id = $8     # previous record's column  8: file's inode number
    nh = $9     # previous record's column  9: number of hardlinks to file
    us = $10    # previous record's column 10: file's user name
    gr = $11    # previous record's column 11: file's group name
    md = $12    # previous record's column 12: file's permission bits (in octal)
    ha = $13    # previous record's column 13: SHA-256 hash of file's contents (if --sha256 option is given)
    pt = $14    # previous record's column 14: file's path with <sourceDir> or <backupDir> stripped
  }
  print
}
AWKHLINKS

if [ ${detectHLinksS} -eq 1 ]; then

  start_progress 'Sorting (1)'

  LC_ALL=C sort -t "${FSTAB}" -k7,7 -k8,8 -k14,14 "${f330}" > "${f350}"

  stop_progress

  optim_csv_after_use "${f330}"

  start_progress 'Hardlinks detecting'

  ${awk} -f "${f150}" "${f350}" > "${f360}"

  stop_progress

  optim_csv_after_use "${f350}"

  fDiffInputSource="${f360}"

else

  fDiffInputSource="${f330}"

  files_not_prepared "${f350}" "${f360}"

fi

################ FLOWCHART STEPS 22 - 24 ##################

${awk} -f "${f100}" << 'AWKDIFF' > "${f170}"
DEFINE_ERROR_EXIT
DEFINE_WARNING
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  lru = 0     # time of the last run of Zaloha
  xkp = ""    # occupied namespace: not possible to KEEP objects only in <backupDir>
  prr = 0     # flag previous record remembered (= unprocessed)
  slc = 0     # count of symbolic links in <sourceDir>
  idc = 0     # count of identical object(s) (inodes) in <sourceDir> and <backupDir>
  idp = ""    # path of first identical object (inode) in <sourceDir> and <backupDir>
  if ( 1 == ok3600s ) {
    tof = 3600     # tolerated offset +/- 3600 seconds
  } else {
    tof = 0
  }
  sb = ""
}
function get_tolerance() {
  if (( ft ~ FATREGEX ) || ( $6 ~ FATREGEX ) || ( 1 == ok2s )) {
    tol = 2        # additional tolerance +/- 2 seconds due to FAT rounding to nearest 2 seconds
  } else {
    tol = 0
  }
}
function print_previous( acode ) {
  print TRIPLET, acode, tp, sz, tm, ft, dv, id,    ";" nh, us, gr, md, ha, pt, TRIPLET, ol, TRIPLET
}
function print_prev_curr( acode ) {
  print TRIPLET, acode, tp, sz, tm, ft, dv, id, $9 ";" nh, us, gr, md, ha, pt, TRIPLET, ol, TRIPLET
}
function print_current( acode ) {
  print TRIPLET, acode, $3, $4, $5, $6, $7, $8, $9 ";"   , $10, $11, $12, $13, $14, TRIPLET, $16, TRIPLET
}
function print_curr_prev( acode ) {
  print TRIPLET, acode, $3, $4, $5, $6, $7, $8, $9 ";" nh, $10, $11, $12, $13, $14, TRIPLET, $16, TRIPLET
}
function remove( unavoidable ) {
  if ( "d" == tp ) {
    print_previous( unavoidable "RMDIR" )
  } else if ( "f" == tp ) {
    if (( 0 != lru ) && ( lru < tm )) {
      print_previous( unavoidable "REMOVE.!" )
    } else {
      print_previous( unavoidable "REMOVE" )
    }
  } else {
    print_previous( unavoidable "REMOVE." tp )
  }
}
function keep_or_remove( no_remove ) {
  if ( 1 == no_remove ) {
    print_previous( "KEEP" )
  } else {
    remove( "" )
  }
}
function try_to_keep_or_remove( no_remove ) {
  if ( "" == xkp ) {
    keep_or_remove( no_remove )
  } else if ( 1 == index( pt, xkp )) {
    remove( "u" )                              #  (unavoidable removal)
  } else {
    keep_or_remove( no_remove )
    xkp = ""
  }
}
function update_file() {
  if (( 0 == noUnlink ) && ( 1 != nh )) {
    bac = "unl.UP"
  } else {
    bac = "UPDATE"
  }
  if (( 0 != lru ) && ( lru < tm )) {
    print_curr_prev( bac ".!" )
  } else {
    if ( tdi <= tof + tol ) {
      print_curr_prev( bac ".?" )
    } else {
      print_curr_prev( bac )
    }
  }
}
function rev_up_file() {
  if (( 0 != lru ) && ( lru < tof + $5 )) {
    print_prev_curr( "REV.UP.!" )
  } else {
    print_prev_curr( "REV.UP" )
  }
}
function attributes_or_ok( atr ) {
  if (( 1 == pMode ) && ( $12 != md ) && ( "l" != tp )) {
    atr = "m" atr
  }
  if (( 1 == pGroup ) && ( $11 != gr )) {
    atr = "g" atr
  }
  if (( 1 == pUser ) && ( $10 != us )) {
    atr = "u" atr
  }
  if ( "" != atr ) {
    print_curr_prev( "ATTR:" atr )
  } else {
    print_curr_prev( "OK" )
  }
}
function process_previous_record() {
  if ( "S" == sb ) {
    if ( "d" == tp ) {                         # directory only in <sourceDir> (case 21)
      print_previous( "MKDIR" )
    } else if ( "f" == tp ) {                  # file only in <sourceDir> (case 22)
      print_previous( "NEW" )
    } else if ( "l" == tp ) {                  # symbolic link only in <sourceDir> (case 24)
      if ( 1 == syncSLinks ) {
         print_previous( "SLINK.n" )           #  (create the symbolic link in <backupDir>)
      } else {
         print_previous( "OK" )                #  (do not create the symbolic link, just produce an OK record for the restore scripts)
      }
      slc ++
    } else {                                   # hardlink or other object only in <sourceDir> (cases 23,25)
      print_previous( "OK" )                   #  (OK record needed for the restore scripts)
    }
  } else {
    if ( "d" == tp ) {                         # directory only in <backupDir> (case 26)
      try_to_keep_or_remove( noRemove )
    } else if ( "f" == tp ) {                  # file only in <backupDir> (case 27)
      if (( 1 == revNew ) && ( 0 != lru ) && ( lru < tm )) {
        if ( "" == xkp ) {
          print_previous( "REV.NEW" )
        } else if ( 1 == index( pt, xkp )) {
          remove( "u" )                        #  (unavoidable removal)
        } else {
          print_previous( "REV.NEW" )
          xkp = ""
        }
      } else {
        try_to_keep_or_remove( noRemove )
      }
    } else if ( "l" == tp ) {                  # symbolic link only in <backupDir> (case 28)
      try_to_keep_or_remove( noRemove )
    } else {                                   # other object only in <backupDir> (case 29)
      try_to_keep_or_remove( 1 )
    }
  }
}
{
  if (( sb == $2 ) && ( pt == $14 )) {
    error_exit( "Unexpected, duplicate record" )
  }
  if ( "L" == $2 ) {
    if ( 1 != NR ) {
      error_exit( "Unexpected, misplaced L record" )
    }
    lru = $5
  } else {
    if ( 1 == prr ) {
      if ( pt == $14 ) {                       ### same path in <sourceDir> and <backupDir>
        if (( 0 == noIdentCheck )                              \
         && ( $7 !~ ZEROREGEX ) && (( "M" dv ) == ( "M" $7 ))  \
         && ( $8 !~ ZEROREGEX ) && (( "M" id ) == ( "M" $8 ))) {
           if ( 0 == idc ) {
             idp = pt
           }
           idc ++
        }
        if ( "d" == $3 ) {                     ## directory in <sourceDir>
          if ( "d" == tp ) {                   # directory in <sourceDir>, directory in <backupDir> (case 1)
            attributes_or_ok( "" )
          } else {                             # directory in <sourceDir>, file, symbolic link or other object in <backupDir> (cases 2,3,4)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "MKDIR" )
          }
        } else if ( "f" == $3 ) {              ## file in <sourceDir>
          if ( "d" == tp ) {                   # file in <sourceDir>, directory in <backupDir> (case 5)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "NEW" )
          } else if ( "f" == tp ) {            # file in <sourceDir>, file in <backupDir> (case 6)
            oka = 0
            oks = 2
            if ( "M" $4 == "M" sz ) {
              if ( "M" $5 == "M" tm ) {
                oka = 1
              } else {
                tdi = $5 - tm                  #  (time difference <sourceDir> file minus <backupDir> file)
                tda = tdi                      #  (time difference absolute value)
                if ( tda < 0 ) {
                  tda = - tda
                }
                if ( 0 == tda ) {
                  error_exit( "Unexpected, numeric overflow occurred" )
                }
                get_tolerance()
                if ( tda <= tol ) {
                  oka = 1
                } else if (( 0 != tof ) && ( tof - tol <= tda ) && ( tda <= tof + tol )) {
                  oka = 1
                }
              }
              if ( "M" $13 != "M" ha ) {
                oks = 0
              } else if ( "0" != $13 ) {
                oks = 1
              }
            } else {
              tdi = $5 - tm
              get_tolerance()
            }
            if ( 1 == oka ) {
              if ( 0 == oks ) {                # size and time OK, but the SHA-256 hash differs
                if (( 0 == noUnlink ) && ( 1 != nh )) {
                  print_curr_prev( "unl.UP.b" )
                } else {
                  print_curr_prev( "UPDATE.b" )
                }
              } else {
                attributes_or_ok( "" )
              }
            } else {
              if ( 1 == oks ) {                # time not OK, but size and SHA-256 match
                attributes_or_ok( "T" )
              } else {
                if ( 1 == revUp ) {
                  if ( tdi < - tof - tol ) {
                    rev_up_file()
                  } else {
                    update_file()
                  }
                } else {
                  update_file()
                }
              }
            }
          } else {                             # file in <sourceDir>, symbolic link or other object in <backupDir> (cases 7,8)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "NEW" )
          }
        } else if ( "h" == $3 ) {              ## hardlink in <sourceDir> (cases 9,10,11,12)
          xkp = pt                             #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
          remove( "u" )                        #  (unavoidable removal, see Corner Cases section)
          print_current( "OK" )                #  (OK record needed for the restore scripts)
        } else if ( "l" == $3 ) {              ## symbolic link in <sourceDir>
          if ( "l" == tp ) {                   # symbolic link in <sourceDir>, symbolic link in <backupDir> (case 15)
            if ( 1 == syncSLinks ) {
              if ( ol == $16 ) {
                attributes_or_ok( "" )         #  (the symbolic links are synchronized (= have identical target paths))
              } else {
                print_curr_prev( "SLINK.u" )   #  (the symbolic links are not synchronized, an "update" is needed)
              }
            } else {
              print_previous( "KEEP" )         #  (keep the symbolic link in <backupDir>, but do not change it)
              print_current( "OK" )            #  (produce an OK record for the restore scripts)
            }
          } else {                             # symbolic link in <sourceDir>, directory, file or other object in <backupDir> (cases 13,14,16)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal, see Corner Cases section)
            if ( 1 == syncSLinks ) {
              print_current( "SLINK.n" )       #  (create the symbolic link in <backupDir>)
            } else {
              print_current( "OK" )            #  (do not create the symbolic link, just produce an OK record for the restore scripts)
            }
          }
          slc ++
        } else {                               ## other object in <sourceDir>
          if ( tp ~ /[dfl]/ ) {                # other object in <sourceDir>, directory, file or symbolic link in <backupDir> (cases 17,18,19)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal, see Corner Cases section)
          } else {                             # other object in <sourceDir>, other object in <backupDir> (case 20)
            print_previous( "KEEP" )           #  (keep the other object in <backupDir>, but do not change it)
          }
          print_current( "OK" )                #  (OK record for keeping in metadata)
        }
        prr = 0
      } else {                                 ### different path in <sourceDir> and <backupDir>
        process_previous_record()
        prr = 1
      }
    } else {
      prr = 1
    }
  }
  sb = $2     # previous record's column  2: S = <sourceDir>, B = <backupDir>, L = last run record
  tp = $3     # previous record's column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
  sz = $4     # previous record's column  4: file's size in bytes
  tm = $5     # previous record's column  5: file's last modification time, seconds since 01/01/1970
  ft = $6     # previous record's column  6: type of the filesystem the file is on
  dv = $7     # previous record's column  7: device number the file is on
  id = $8     # previous record's column  8: file's inode number
  nh = $9     # previous record's column  9: number of hardlinks to file
  us = $10    # previous record's column 10: file's user name
  gr = $11    # previous record's column 11: file's group name
  md = $12    # previous record's column 12: file's permission bits (in octal)
  ha = $13    # previous record's column 13: SHA-256 hash of file's contents (if --sha256 option is given)
  pt = $14    # previous record's column 14: file's path with <sourceDir> or <backupDir> stripped
  ol = $16    # previous record's column 16: target path of symbolic link [path of first link (the "file") for a hardlink]
}
END {
  if ( 1 == prr ) {
    process_previous_record()
  }
  if (( 0 == syncSLinks ) && ( 0 == noWarnSLinks ) && ( 0 != slc )) {
    if ( 1 == followSLinksS ) {
      warning( slc " broken symbolic link(s) in <sourceDir> that are not synchronized to <backupDir>:" \
                   " they are saved in the CSV metadata and in the restore script 820" )
    } else {
      warning( slc " symbolic link(s) in <sourceDir> that are neither followed nor synchronized to <backupDir>:" \
                   " they are saved in the CSV metadata and in the restore script 820" )
    }
  }
  if ( 0 != idc ) {
    if ( "" == idp ) {
      warning( idc " identical object(s) (inodes) in <sourceDir> and <backupDir>, first are <sourceDir> and <backupDir> themselves" )
    } else {
      gsub( TRIPLETSREGEX, SLASH, idp )
      idp = substr( idp, 1, length( idp ) - 1 )
      warning( idc " identical object(s) (inodes) in <sourceDir> and <backupDir>, path of first case: " idp )
    }
  }
  if (( 0 == noLastRun ) && ( 0 == lru )) {
    warning( "No last run of Zaloha found (this is OK if this is the first run)" )
  }
}
AWKDIFF

start_progress 'Sorting (2)'

LC_ALL=C sort -t "${FSTAB}" -k14,14 -k2,2 "${fDiffInputSource}" "${f340}" > "${f370}"

stop_progress

optim_csv_after_use "${fDiffInputSource}" "${f340}"

start_progress 'Differences processing'

${awk} -f "${f170}"                       \
       -v noRemove=${noRemove}            \
       -v revNew=${revNew}                \
       -v revUp=${revUp}                  \
       -v ok2s=${ok2s}                    \
       -v ok3600s=${ok3600s}              \
       -v noUnlink=${noUnlink}            \
       -v pUser=${pUser}                  \
       -v pGroup=${pGroup}                \
       -v pMode=${pMode}                  \
       -v followSLinksS=${followSLinksS}  \
       -v syncSLinks=${syncSLinks}        \
       -v noWarnSLinks=${noWarnSLinks}    \
       -v noLastRun=${noLastRun}          \
       -v noIdentCheck=${noIdentCheck}    \
       "${fLastRun}" "${f370}"            > "${f380}"

stop_progress

optim_csv_after_use "${f370}"

################ FLOWCHART STEPS 25 - 27 ##################

${awk} -f "${f100}" << 'AWKPOSTPROC' > "${f190}"
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  gsub( TRIPLETBREGEX, BSLASH, f510 )
  gsub( TRIPLETBREGEX, BSLASH, f540 )
  printf "" > f510
  if ( 0 == noRemove ) {
    printf "" > f540
  }
  lrn = ""    # path of last file to REV.NEW
  lkp = ""    # path of last object to KEEP only in <backupDir>
}
{
  if ( $2 ~ /^REV\.NEW/ ) {
    lrn = $14                # remember path of last file to REV.NEW
  } else if ( $2 ~ /^KEEP/ ) {
    if (( "d" == $3 ) && ( 1 == index( lrn, $14 ))) {
      $2 = "REV.MKDI"        # convert KEEP to REV.MKDI on parent directory of a file to REV.NEW
    } else {
      lkp = $14              # remember path of last object to KEEP only in <backupDir>
    }
  } else if ( $2 ~ /^RMDIR/ ) {
    if ( 1 == index( lrn, $14 )) {
      $2 = "REV.MKDI"        # convert RMDIR to REV.MKDI on parent directory of a file to REV.NEW
    } else if ( 1 == index( lkp, $14 )) {
      $2 = "KEEP"            # convert RMDIR to KEEP on parent directory of an object to KEEP only in <backupDir>
    }
  } else if ( "d" == $3 ) {  # encountered a directory with neither KEEP nor RMDIR: safe to forget lrn and lkp
    lrn = ""
    lkp = ""
  }
  # modifications done, split off 510 and 540 data, output remaining data
  if ( $2 ~ /^(uRMDIR|uREMOVE)/ ) {
    $2 = substr( $2, 2 )
    if ( "" != $14 ) {
      gsub( TRIPLETSREGEX, SLASH, $14 )
      $14 = substr( $14, 1, length( $14 ) - 1 )
    }
    print > f510
  } else if ( $2 ~ /^(RMDIR|REMOVE)/ ) {
    if ( "" != $14 ) {
      gsub( TRIPLETSREGEX, SLASH, $14 )
      $14 = substr( $14, 1, length( $14 ) - 1 )
    }
    print > f540
  } else {
    print
  }
}
END {
  if ( 0 == noRemove ) {
    close( f540 )
  }
  close( f510 )
}
AWKPOSTPROC

start_progress 'Sorting (3)'

LC_ALL=C sort -t "${FSTAB}" -k14r,14 -k2,2 "${f380}" > "${f390}"

stop_progress

optim_csv_after_use "${f380}"

tmpVal='Exec1'

if [ ${noRemove} -eq 0 ]; then

  tmpVal+=' and Exec4'

else

  files_not_prepared "${f540}"

fi

start_progress "Post-processing and splitting off ${tmpVal}"

${awk} -f "${f190}"             \
       -v f510="${f510Awk}"     \
       -v f540="${f540Awk}"     \
       -v noRemove=${noRemove}  \
       "${f390}"                > "${f500}"

stop_progress

optim_csv_after_use "${f390}"

################ FLOWCHART STEPS 28 - 29 ##################

${awk} -f "${f100}" << 'AWKSELECT23' > "${f405}"
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  gsub( TRIPLETBREGEX, BSLASH, f520 )
  gsub( TRIPLETBREGEX, BSLASH, f530 )
  gsub( TRIPLETBREGEX, BSLASH, f550 )
  printf "" > f520
  if (( 1 == revNew ) || ( 1 == revUp )) {
    printf "" > f530
  }
  if ( 1 == sha256 ) {
    printf "" > f550
  }
}
{
  if ( "" != $14 ) {
    gsub( TRIPLETSREGEX, SLASH, $14 )
    $14 = substr( $14, 1, length( $14 ) - 1 )
  }
  if ( $2 ~ /^(UPDATE\.b|unl\.UP\.b)/ ) {
    print > f550
  } else if ( $2 ~ /^(MKDIR|NEW|UPDATE|unl\.UP|SLINK|ATTR)/ ) {
    print > f520
  } else if ( $2 ~ /^(REV\.MKDI|REV\.NEW|REV\.UP)/ ) {
    print > f530
  }
  print
}
END {
  if ( 1 == sha256 ) {
    close( f550 )
  }
  if (( 1 == revNew ) || ( 1 == revUp )) {
    close( f530 )
  }
  close( f520 )
}
AWKSELECT23

tmpVal='Exec2'

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then

  tmpVal+=', Exec3'

else

  files_not_prepared "${f530}"

fi

if [ ${sha256} -eq 1 ]; then

  tmpVal+=', Exec5'

elif [ ${byteByByte} -eq 0 ]; then

  files_not_prepared "${f550}"

fi

start_progress "Sorting (4) and selecting ${tmpVal}"

LC_ALL=C sort -t "${FSTAB}" -k14,14 -k2,2 "${f500}" | ${awk} -f "${f405}"  \
    -v f520="${f520Awk}"  \
    -v f530="${f530Awk}"  \
    -v f550="${f550Awk}"  \
    -v revNew=${revNew}   \
    -v revUp=${revUp}     \
    -v sha256=${sha256}   > "${f505}"

stop_progress

optim_csv_after_use "${f500}"

copyToRemoteBackup+=( "${f505}" )

################ FLOWCHART STEP 30 ########################

if [ ${byteByByte} -eq 1 ]; then

  start_progress_by_chars 'Byte by byte comparing files that appear identical'

  exec {fd550}> "${f550}"
  exec {fd555}> "${f555}"

  while IFS= read -r tmpVal       # Note: read -r -a would treat consecutive tab separators as one: hence this approach
  do
    tmpRec=()
    for i in {1..16}; do
      tmpRec+=( "${tmpVal%%${FSTAB}*}" )
      tmpVal="${tmpVal#*${FSTAB}}"
    done
    tmpRec+=( "${tmpVal}" )

    if [ "${tmpRec[2]}" == 'f' ]; then
      if [ "${tmpRec[1]}" == 'OK' ] || [ "${tmpRec[1]:0:4}" == 'ATTR' ]; then

        tmpVal="${tmpRec[13]}"    # file's path with <sourceDir> or <backupDir> stripped
        tmpVal="${tmpVal//${TRIPLETN}/${NLINE}}"
        tmpVal="${tmpVal//${TRIPLETT}/${TAB}}"

        cmp -s "${sourceDir}${tmpVal}" "${backupDir}${tmpVal}" && tmpVal=$? || tmpVal=$?

        if [ ${tmpVal} -eq 0 ]; then
          tmpRec[1]='OK.b'
          progress_char '.'

        elif [ ${tmpVal} -eq 1 ]; then

          tmpVal="${tmpRec[8]}"   # number of hardlinks <sourceDir> ; number of hardlinks <backupDir>

          if [ ${noUnlink} -eq 0 ] && [ ${tmpVal#*;} -ne 1 ]; then
            tmpRec[1]='unl.UP.b'
          else
            tmpRec[1]='UPDATE.b'
          fi
          printf "${RECFMT}" "${tmpRec[@]}" >&${fd550}
          progress_char '#'

        else
          error_exit 'command CMP failed while comparing files byte by byte'
        fi

        printf "${RECFMT}" "${tmpRec[@]}" >&${fd555}
      fi
    fi
  done < "${f505}"

  exec {fd555}>&-
  exec {fd550}>&-

  stop_progress

else

  files_not_prepared "${f555}"

fi

################ FLOWCHART STEPS 31 - 32 ##################

${awk} -f "${f100}" << 'AWKEXEC1' > "${f410}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  if ( 0 == no610Hdr ) {
    BIN_BASH
    print "backupDir='" backupDir "'"
    print "RMDIR='rmdir'"
    print "RM" ONE_TO_MAXPARALLEL "='rm -f'"
    print "set -u"
    if ( 0 == noExec ) {
      print "set -e"
      XTRACE_ON
    }
  }
  SECTION_LINE
}
{
  pt = $14
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETTREGEX, TAB, pt )
  gsub( QUOTEREGEX, QUOTEESC, pt )
  b = "\"${backupDir}\"'" pt "'"
  if ( $2 ~ /^RMDIR/ ) {
    print "${RMDIR} " b
  } else if ( $2 ~ /^REMOVE/ ) {
    print "${RM" pin "} " b
    if ( MAXPARALLEL <= pin ) {
      pin = 1
    } else {
      pin ++
    }
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE
}
AWKEXEC1

start_progress 'Preparing shellscript for Exec1'

${awk} -f "${f410}"                    \
       -v backupDir="${backupDirAwk}"  \
       -v noExec=${noExec}             \
       -v no610Hdr=${no610Hdr}         \
       "${f510}"                       > "${f610}"

stop_progress

copyToRemoteBackup+=( "${f610}" )

################ FLOWCHART STEPS 33 - 34 ##################

${awk} -f "${f100}" << 'AWKEXEC2' > "${f420}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, sourceDir )
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( TRIPLETBREGEX, BSLASH, sourceUserHost )
  gsub( TRIPLETBREGEX, BSLASH, backupUserHost )
  gsub( TRIPLETBREGEX, BSLASH, scpExecOpt )
  gsub( TRIPLETBREGEX, BSLASH, cpExecOpt )
  gsub( TRIPLETBREGEX, BSLASH, f621 )
  gsub( TRIPLETBREGEX, BSLASH, f622 )
  gsub( TRIPLETBREGEX, BSLASH, f623 )
  sourceDirScp = sourceDir
  backupDirScp = backupDir
  gsub( QUOTEREGEX, QUOTEESC, sourceDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, sourceUserHost )
  gsub( QUOTEREGEX, QUOTEESC, backupUserHost )
  gsub( QUOTEREGEX, QUOTEESC, scpExecOpt )
  gsub( QUOTEREGEX, QUOTEESC, cpExecOpt )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", sourceDirScp )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", backupDirScp )
  if ( 0 == no621Hdr ) {
    BIN_BASH > f621
    print "backupDir='" backupDir "'" > f621
    print "MKDIR='mkdir'" > f621
    if ( 1 == pUser ) {
      print "CHOWN_DIR='chown'" > f621
    }
    if ( 1 == pGroup ) {
      print "CHGRP_DIR='chgrp'" > f621
    }
    if ( 1 == pMode ) {
      print "CHMOD_DIR='chmod'" > f621
    }
    if ( 0 == noUnlink ) {
      print "UNLINK" ONE_TO_MAXPARALLEL "='rm -f'" > f621
    }
    print "set -u" > f621
    if ( 0 == noExec ) {
      print "set -e" > f621
      XTRACE_ON > f621
    }
  }
  if ( 0 == no622Hdr ) {
    BIN_BASH > f622
    if ( 1 == remoteSource ) {
      print "sourceUserHostDirScp='" sourceUserHost ":'" QUOTESCP "'" sourceDirScp "'" QUOTESCP > f622
    } else {
      print "sourceDir='" sourceDir "'" > f622
    }
    if ( 1 == remoteBackup ) {
      print "backupUserHostDirScp='" backupUserHost ":'" QUOTESCP "'" backupDirScp "'" QUOTESCP > f622
    } else {
      print "backupDir='" backupDir "'" > f622
    }
    if (( 1 == remoteSource ) || ( 1 == remoteBackup )) {
      print "SCP" ONE_TO_MAXPARALLEL "='scp " scpExecOpt "'" > f622
    } else {
      print "CP" ONE_TO_MAXPARALLEL "='cp " cpExecOpt "'" > f622
      print "TOUCH" ONE_TO_MAXPARALLEL "='touch -m -r'" > f622
    }
    print "set -u" > f622
    if ( 0 == noExec ) {
      print "set -e" > f622
      XTRACE_ON_CP > f622
    }
  }
  if ( 0 == no623Hdr ) {
    BIN_BASH > f623
    print "backupDir='" backupDir "'" > f623
    if (( 1 == remoteSource ) || ( 1 == remoteBackup )) {
      print "STOUCH" ONE_TO_MAXPARALLEL "='touch -m -d'" > f623
    }
    if ( 1 == syncSLinks ) {
      print "UNLINK" ONE_TO_MAXPARALLEL "='rm -f'" > f623
      print "LNSYMB" ONE_TO_MAXPARALLEL "='ln -s --'" > f623
    }
    if ( 1 == pUser ) {
      print "CHOWN" ONE_TO_MAXPARALLEL "='chown'" > f623
      if ( 1 == syncSLinks ) {
        print "CHOWN_LNSYMB" ONE_TO_MAXPARALLEL "='chown -h'" > f623
      }
    }
    if ( 1 == pGroup ) {
      print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'" > f623
      if ( 1 == syncSLinks ) {
        print "CHGRP_LNSYMB" ONE_TO_MAXPARALLEL "='chgrp -h'" > f623
      }
    }
    if ( 1 == pMode ) {
      print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'" > f623
    }
    print "set -u" > f623
    if ( 0 == noExec ) {
      print "set -e" > f623
      XTRACE_ON > f623
    }
  }
  SECTION_LINE > f621
  SECTION_LINE > f622
  SECTION_LINE > f623
}
function apply_attr_dir() {
  if ( 1 == pUser ) {
    print "${CHOWN_DIR} " u " " b > f621
  }
  if ( 1 == pGroup ) {
    print "${CHGRP_DIR} " g " " b > f621
  }
  if ( 1 == pMode ) {
    print "${CHMOD_DIR} " m " " b > f621
  }
}
function copy_file() {
  if ( 1 == remoteSource ) {
    print "${SCP" pin "} " sScp " " b > f622
    print "${STOUCH" pin "} @" $5 " " b > f623
  } else if ( 1 == remoteBackup ) {
    print "${SCP" pin "} " s " " bScp > f622
    print "${STOUCH" pin "} @" $5 " " b > f623
  } else {
    print "${CP" pin "} " s " " b > f622
    if ( 1 == extraTouch ) {
      print "${TOUCH" pin "} " s " " b > f622
    }
  }
}
function apply_attr() {
  if ( 1 == pUser ) {
    print "${CHOWN" pin "} " u " " b > f623
  }
  if ( 1 == pGroup ) {
    print "${CHGRP" pin "} " g " " b > f623
  }
  if ( 1 == pMode ) {
    print "${CHMOD" pin "} " m " " b > f623
  }
}
function apply_attr_lnsymb() {
  if ( 1 == pUser ) {
    print "${CHOWN_LNSYMB" pin "} " u " " b > f623
  }
  if ( 1 == pGroup ) {
    print "${CHGRP_LNSYMB" pin "} " g " " b > f623
  }
}
function next_pin() {
  if ( MAXPARALLEL <= pin ) {
    pin = 1
  } else {
    pin ++
  }
}
{
  us = $10
  gr = $11
  md = $12
  pt = $14
  ol = $16
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETNREGEX, NLINE, ol )
  gsub( TRIPLETTREGEX, TAB, pt )
  gsub( TRIPLETTREGEX, TAB, ol )
  if ( "l" == $3 ) {
    gsub( TRIPLETSREGEX, SLASH, ol )
  }
  ptScp = pt
  gsub( QUOTEREGEX, QUOTEESC, us )
  gsub( QUOTEREGEX, QUOTEESC, gr )
  gsub( QUOTEREGEX, QUOTEESC, pt )
  gsub( QUOTEREGEX, QUOTEESC, ol )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", ptScp )
  u = "'" us "'"
  g = "'" gr "'"
  m = "'" md "'"
  s = "\"${sourceDir}\"'" pt "'"
  b = "\"${backupDir}\"'" pt "'"
  sScp = "\"${sourceUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
  bScp = "\"${backupUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
  if ( $2 ~ /^MKDIR/ ) {
    print "${MKDIR} " b > f621
    apply_attr_dir()
  } else if ( $2 ~ /^NEW/ ) {
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^UPDATE/ ) {
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^unl\.UP/ ) {
    print "${UNLINK" pin "} " b > f621
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^SLINK/ ) {
    if ( $2 ~ /u/ ) {
      print "${UNLINK" pin "} " b > f623
    }
    print "${LNSYMB" pin "} '" ol "' " b > f623
    apply_attr_lnsymb()
    next_pin()
  } else if ( $2 ~ /^ATTR/ ) {
    if ( "l" == $3 ) {
      if ( $2 ~ /u/ ) {
        print "${CHOWN_LNSYMB" pin "} " u " " b > f623
      }
      if ( $2 ~ /g/ ) {
        print "${CHGRP_LNSYMB" pin "} " g " " b > f623
      }
    } else {
      if ( $2 ~ /u/ ) {
        print "${CHOWN" pin "} " u " " b > f623
      }
      if ( $2 ~ /g/ ) {
        print "${CHGRP" pin "} " g " " b > f623
      }
      if ( $2 ~ /m/ ) {
        print "${CHMOD" pin "} " m " " b > f623
      }
      if ( $2 ~ /T$/ ) {
        if (( 1 == remoteSource ) || ( 1 == remoteBackup )) {
          print "${STOUCH" pin "} @" $5 " " b > f623
        } else {
          print "${TOUCH" pin "} " s " " b > f622
        }
      }
    }
    next_pin()
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE > f623
  SECTION_LINE > f622
  SECTION_LINE > f621
  close( f623 )
  close( f622 )
  close( f621 )
}
AWKEXEC2

start_progress 'Preparing shellscripts for Exec2'

${awk} -f "${f420}"                              \
       -v sourceDir="${sourceDirAwk}"            \
       -v backupDir="${backupDirAwk}"            \
       -v remoteSource=${remoteSource}           \
       -v sourceUserHost="${sourceUserHostAwk}"  \
       -v remoteBackup=${remoteBackup}           \
       -v backupUserHost="${backupUserHostAwk}"  \
       -v scpExecOpt="${scpExecOptAwk}"          \
       -v noExec=${noExec}                       \
       -v noUnlink=${noUnlink}                   \
       -v extraTouch=${extraTouch}               \
       -v cpExecOpt=${cpExecOptAwk}              \
       -v pUser=${pUser}                         \
       -v pGroup=${pGroup}                       \
       -v pMode=${pMode}                         \
       -v syncSLinks=${syncSLinks}               \
       -v no621Hdr=${no621Hdr}                   \
       -v no622Hdr=${no622Hdr}                   \
       -v no623Hdr=${no623Hdr}                   \
       -v f621="${f621Awk}"                      \
       -v f622="${f622Awk}"                      \
       -v f623="${f623Awk}"                      \
       "${f520}"

stop_progress

copyToRemoteBackup+=( "${f621}" "${f623}" )

################ FLOWCHART STEPS 35 - 36 ##################

${awk} -f "${f100}" << 'AWKEXEC3' > "${f430}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, sourceDir )
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( TRIPLETBREGEX, BSLASH, sourceUserHost )
  gsub( TRIPLETBREGEX, BSLASH, backupUserHost )
  gsub( TRIPLETBREGEX, BSLASH, scpExecOpt )
  gsub( TRIPLETBREGEX, BSLASH, cpExecOpt )
  gsub( TRIPLETBREGEX, BSLASH, f631 )
  gsub( TRIPLETBREGEX, BSLASH, f632 )
  gsub( TRIPLETBREGEX, BSLASH, f633 )
  sourceDirScp = sourceDir
  backupDirScp = backupDir
  gsub( QUOTEREGEX, QUOTEESC, sourceDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, sourceUserHost )
  gsub( QUOTEREGEX, QUOTEESC, backupUserHost )
  gsub( QUOTEREGEX, QUOTEESC, scpExecOpt )
  gsub( QUOTEREGEX, QUOTEESC, cpExecOpt )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", sourceDirScp )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", backupDirScp )
  if ( 0 == no631Hdr ) {
    BIN_BASH > f631
    print "sourceDir='" sourceDir "'" > f631
    print "function rev_exists_err {" > f631
    XTRACE_OFF > f631
    print "  printf 'Zaloha: Object exists in <sourceDir> (masked by <findSourceOps> ?): %s\\n' \"${1}\" >&2" > f631
    if ( 0 == noExec ) {
      print "  exit 1" > f631
    }
    print "}" > f631
    print "TEST_DIR='['" > f631
    print "REV_EXISTS_ERR_DIR='rev_exists_err'" > f631
    print "MKDIR='mkdir'" > f631
    if ( 1 == pRevUser ) {
      print "CHOWN_DIR='chown'" > f631
    }
    if ( 1 == pRevGroup ) {
      print "CHGRP_DIR='chgrp'" > f631
    }
    if ( 1 == pRevMode ) {
      print "CHMOD_DIR='chmod'" > f631
    }
    print "TEST" ONE_TO_MAXPARALLEL "='['" > f631
    print "REV_EXISTS_ERR" ONE_TO_MAXPARALLEL "='rev_exists_err'" > f631
    print "set -u" > f631
    if ( 0 == noExec ) {
      print "set -e" > f631
      XTRACE_ON > f631
    }
  }
  if ( 0 == no632Hdr ) {
    BIN_BASH > f632
    if ( 1 == remoteSource ) {
      print "sourceUserHostDirScp='" sourceUserHost ":'" QUOTESCP "'" sourceDirScp "'" QUOTESCP > f632
    } else {
      print "sourceDir='" sourceDir "'" > f632
    }
    if ( 1 == remoteBackup ) {
      print "backupUserHostDirScp='" backupUserHost ":'" QUOTESCP "'" backupDirScp "'" QUOTESCP > f632
    } else {
      print "backupDir='" backupDir "'" > f632
    }
    if (( 1 == remoteSource ) || ( 1 == remoteBackup )) {
      print "SCP" ONE_TO_MAXPARALLEL "='scp " scpExecOpt "'" > f632
    } else {
      print "CP" ONE_TO_MAXPARALLEL "='cp " cpExecOpt "'" > f632
      if ( 1 == extraTouch ) {
        print "TOUCH" ONE_TO_MAXPARALLEL "='touch -m -r'" > f632
      }
    }
    print "set -u" > f632
    if ( 0 == noExec ) {
      print "set -e" > f632
      XTRACE_ON_CP > f632
    }
  }
  if ( 0 == no633Hdr ) {
    BIN_BASH > f633
    print "sourceDir='" sourceDir "'" > f633
    if (( 1 == remoteSource ) || ( 1 == remoteBackup )) {
      print "STOUCH" ONE_TO_MAXPARALLEL "='touch -m -d'" > f633
    }
    if ( 1 == pRevUser ) {
      print "CHOWN" ONE_TO_MAXPARALLEL "='chown'" > f633
    }
    if ( 1 == pRevGroup ) {
      print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'" > f633
    }
    if ( 1 == pRevMode ) {
      print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'" > f633
    }
    print "set -u" > f633
    if ( 0 == noExec ) {
      print "set -e" > f633
      XTRACE_ON > f633
    }
  }
  SECTION_LINE > f631
  SECTION_LINE > f632
  SECTION_LINE > f633
}
function rev_check_nonex_dir() {
  print "${TEST_DIR} ! -e " s " ] || ${REV_EXISTS_ERR_DIR} '" ptt "'" > f631
}
function rev_apply_attr_dir() {
  if ( 1 == pRevUser ) {
    print "${CHOWN_DIR} " u " " s > f631
  }
  if ( 1 == pRevGroup ) {
    print "${CHGRP_DIR} " g " " s > f631
  }
  if ( 1 == pRevMode ) {
    print "${CHMOD_DIR} " m " " s > f631
  }
}
function rev_check_nonex() {
  print "${TEST" pin "} ! -e " s " ] || ${REV_EXISTS_ERR" pin "} '" ptt "'" > f631
}
function rev_copy_file() {
  if ( 1 == remoteSource ) {
    print "${SCP" pin "} " b " " sScp > f632
    print "${STOUCH" pin "} @" $5 " " s > f633
  } else if ( 1 == remoteBackup ) {
    print "${SCP" pin "} " bScp " " s > f632
    print "${STOUCH" pin "} @" $5 " " s > f633
  } else {
    print "${CP" pin "} " b " " s > f632
    if ( 1 == extraTouch ) {
      print "${TOUCH" pin "} " b " " s > f632
    }
  }
}
function rev_apply_attr() {
  if ( 1 == pRevUser ) {
    print "${CHOWN" pin "} " u " " s > f633
  }
  if ( 1 == pRevGroup ) {
    print "${CHGRP" pin "} " g " " s > f633
  }
  if ( 1 == pRevMode ) {
    print "${CHMOD" pin "} " m " " s > f633
  }
}
function next_pin() {
  if ( MAXPARALLEL <= pin ) {
    pin = 1
  } else {
    pin ++
  }
}
{
  us = $10
  gr = $11
  md = $12
  pt = $14
  ptt = pt
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETTREGEX, TAB, pt )
  gsub( CNTRLREGEX, TRIPLETC, ptt )
  ptScp = pt
  gsub( QUOTEREGEX, QUOTEESC, us )
  gsub( QUOTEREGEX, QUOTEESC, gr )
  gsub( QUOTEREGEX, QUOTEESC, pt )
  gsub( QUOTEREGEX, QUOTEESC, ptt )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", ptScp )
  u = "'" us "'"
  g = "'" gr "'"
  m = "'" md "'"
  s = "\"${sourceDir}\"'" pt "'"
  b = "\"${backupDir}\"'" pt "'"
  sScp = "\"${sourceUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
  bScp = "\"${backupUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
  if ( $2 ~ /^REV\.MKDI/ ) {
    rev_check_nonex_dir()
    print "${MKDIR} " s > f631
    rev_apply_attr_dir()
  } else if ( $2 ~ /^REV\.NEW/ ) {
    rev_check_nonex()
    rev_copy_file()
    rev_apply_attr()
    next_pin()
  } else if ( $2 ~ /^REV\.UP/ ) {
    rev_copy_file()
    rev_apply_attr()
    next_pin()
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE > f633
  SECTION_LINE > f632
  SECTION_LINE > f631
  close( f633 )
  close( f632 )
  close( f631 )
}
AWKEXEC3

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then

  start_progress 'Preparing shellscripts for Exec3'

  ${awk} -f "${f430}"                              \
         -v sourceDir="${sourceDirAwk}"            \
         -v backupDir="${backupDirAwk}"            \
         -v remoteSource=${remoteSource}           \
         -v sourceUserHost="${sourceUserHostAwk}"  \
         -v remoteBackup=${remoteBackup}           \
         -v backupUserHost="${backupUserHostAwk}"  \
         -v scpExecOpt="${scpExecOptAwk}"          \
         -v noExec=${noExec}                       \
         -v extraTouch=${extraTouch}               \
         -v cpExecOpt=${cpExecOptAwk}              \
         -v pRevUser=${pRevUser}                   \
         -v pRevGroup=${pRevGroup}                 \
         -v pRevMode=${pRevMode}                   \
         -v no631Hdr=${no631Hdr}                   \
         -v no632Hdr=${no632Hdr}                   \
         -v no633Hdr=${no633Hdr}                   \
         -v f631="${f631Awk}"                      \
         -v f632="${f632Awk}"                      \
         -v f633="${f633Awk}"                      \
         "${f530}"

  stop_progress

  copyToRemoteSource+=( "${f631}" "${f633}" )

else

  files_not_prepared "${f631}" "${f632}" "${f633}"

  removeFromRemoteSource+="${f631RemoteSourceScp} ${f633RemoteSourceScp} "

  if [ -e "${f530}" ]; then
    error_exit 'Unexpected, REV actions prepared although neither --revNew nor --revUp option given'
  fi

fi

################ FLOWCHART STEP 37 ########################

if [ ${noRemove} -eq 0 ]; then

  start_progress 'Preparing shellscript for Exec4'

  ${awk} -f "${f410}"                    \
         -v backupDir="${backupDirAwk}"  \
         -v noExec=${noExec}             \
         -v no610Hdr=${no640Hdr}         \
         "${f540}"                       > "${f640}"

  stop_progress

  copyToRemoteBackup+=( "${f640}" )

else

  files_not_prepared "${f640}"

  removeFromRemoteBackup+="${f640RemoteBackupScp} "

  if [ -e "${f540}" ]; then
    error_exit 'Unexpected, avoidable removals prepared although --noRemove option given'
  fi

fi

################ FLOWCHART STEP 38 ########################

if [ ${byteByByte} -eq 1 ] || [ ${sha256} -eq 1 ]; then

  start_progress 'Preparing shellscripts for Exec5'

  ${awk} -f "${f420}"                              \
         -v sourceDir="${sourceDirAwk}"            \
         -v backupDir="${backupDirAwk}"            \
         -v remoteSource=${remoteSource}           \
         -v sourceUserHost="${sourceUserHostAwk}"  \
         -v remoteBackup=${remoteBackup}           \
         -v backupUserHost="${backupUserHostAwk}"  \
         -v scpExecOpt="${scpExecOptAwk}"          \
         -v noExec=${noExec}                       \
         -v noUnlink=${noUnlink}                   \
         -v extraTouch=${extraTouch}               \
         -v cpExecOpt=${cpExecOptAwk}              \
         -v pUser=${pUser}                         \
         -v pGroup=${pGroup}                       \
         -v pMode=${pMode}                         \
         -v syncSLinks=0                           \
         -v no621Hdr=${no651Hdr}                   \
         -v no622Hdr=${no652Hdr}                   \
         -v no623Hdr=${no653Hdr}                   \
         -v f621="${f651Awk}"                      \
         -v f622="${f652Awk}"                      \
         -v f623="${f653Awk}"                      \
         "${f550}"

  stop_progress

  copyToRemoteBackup+=( "${f651}" "${f653}" )

else

  files_not_prepared "${f651}" "${f652}" "${f653}"

  removeFromRemoteBackup+="${f651RemoteBackupScp} ${f653RemoteBackupScp} "

  if [ -e "${f550}" ]; then
    error_exit 'Unexpected, copies resulting from comparing contents of files prepared although neither --byteByByte nor --sha256 option given'
  fi

fi

################ FLOWCHART STEPS 39 - 40 ##################

${awk} -f "${f100}" << 'AWKTOUCH' > "${f490}"
BEGIN {
  gsub( TRIPLETBREGEX, BSLASH, metaDir )
  gsub( QUOTEREGEX, QUOTEESC, metaDir )
  BIN_BASH
  print "metaDir='" metaDir "'"
  print "TOUCH='touch -m -r'"
  print "set -u"
  SECTION_LINE
  print "${TOUCH} \"${metaDir}\"" f000Base \
                " \"${metaDir}\"" f999Base
  SECTION_LINE
}
AWKTOUCH

start_progress 'Preparing shellscript to touch file 999'

${awk} -f "${f490}"                \
       -v metaDir="${metaDirAwk}"  \
       -v f000Base="${f000Base}"   \
       -v f999Base="${f999Base}"   > "${f690}"

stop_progress

copyToRemoteBackup+=( "${f690}" )

################ FLOWCHART STEPS 41 - 42 ##################

${awk} -f "${f100}" << 'AWKRESTORE' > "${f700}"
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( TRIPLETBREGEX, BSLASH, restoreDir )
  gsub( TRIPLETBREGEX, BSLASH, backupUserHost )
  gsub( TRIPLETBREGEX, BSLASH, restoreUserHost )
  gsub( TRIPLETBREGEX, BSLASH, scpExecOpt )
  gsub( TRIPLETBREGEX, BSLASH, cpRestoreOpt )
  gsub( TRIPLETBREGEX, BSLASH, f800 )
  gsub( TRIPLETBREGEX, BSLASH, f810 )
  gsub( TRIPLETBREGEX, BSLASH, f820 )
  gsub( TRIPLETBREGEX, BSLASH, f830 )
  gsub( TRIPLETBREGEX, BSLASH, f840 )
  gsub( TRIPLETBREGEX, BSLASH, f850 )
  gsub( TRIPLETBREGEX, BSLASH, f860 )
  gsub( TRIPLETBREGEX, BSLASH, f870 )
  backupDirScp = backupDir
  restoreDirScp = restoreDir
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, restoreDir )
  gsub( QUOTEREGEX, QUOTEESC, backupUserHost )
  gsub( QUOTEREGEX, QUOTEESC, restoreUserHost )
  gsub( QUOTEREGEX, QUOTEESC, scpExecOpt )
  gsub( QUOTEREGEX, QUOTEESC, cpRestoreOpt )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", backupDirScp )
  gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", restoreDirScp )
  if ( 0 == noR800Hdr ) {
    BIN_BASH > f800
    print "restoreDir='" restoreDir "'" > f800
    print "MKDIR='mkdir'" > f800
    print "set -u" > f800
  }
  if ( 0 == noR810Hdr ) {
    BIN_BASH > f810
    if ( 1 == remoteBackup ) {
      print "backupUserHostDirScp='" backupUserHost ":'" QUOTESCP "'" backupDirScp "'" QUOTESCP > f810
    } else {
      print "backupDir='" backupDir "'" > f810
    }
    if ( 1 == remoteRestore ) {
      print "restoreUserHostDirScp='" restoreUserHost ":'" QUOTESCP "'" restoreDirScp "'" QUOTESCP > f810
    } else {
      print "restoreDir='" restoreDir "'" > f810
    }
    if (( 1 == remoteBackup ) || ( 1 == remoteRestore )) {
      print "SCP" ONE_TO_MAXPARALLEL "='scp " scpExecOpt "'" > f810
    } else {
      print "CP" ONE_TO_MAXPARALLEL "='cp " cpRestoreOpt "'" > f810
    }
    print "set -u" > f810
  }
  if ( 0 == noR820Hdr ) {
    BIN_BASH > f820
    print "restoreDir='" restoreDir "'" > f820
    print "LNSYMB='ln -s --'" > f820
    print "set -u" > f820
  }
  if ( 0 == noR830Hdr ) {
    BIN_BASH > f830
    print "restoreDir='" restoreDir "'" > f830
    print "LNHARD='ln'" > f830
    print "set -u" > f830
  }
  if ( 0 == noR840Hdr ) {
    BIN_BASH > f840
    print "restoreDir='" restoreDir "'" > f840
    print "CHOWN_DIR='chown'" > f840
    print "CHOWN" ONE_TO_MAXPARALLEL "='chown'" > f840
    print "CHOWN_LNSYMB='chown -h'" > f840
    print "set -u" > f840
  }
  if ( 0 == noR850Hdr ) {
    BIN_BASH > f850
    print "restoreDir='" restoreDir "'" > f850
    print "CHGRP_DIR='chgrp'" > f850
    print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'" > f850
    print "CHGRP_LNSYMB='chgrp -h'" > f850
    print "set -u" > f850
  }
  if ( 0 == noR860Hdr ) {
    BIN_BASH > f860
    print "restoreDir='" restoreDir "'" > f860
    print "CHMOD_DIR='chmod'" > f860
    print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'" > f860
    print "set -u" > f860
  }
  if ( 0 == noR870Hdr ) {
    BIN_BASH > f870
    if (( 1 == remoteBackup ) || ( 1 == remoteRestore )) {
      print "restoreDir='" restoreDir "'" > f870
      print "STOUCH" ONE_TO_MAXPARALLEL "='touch -m -d'" > f870
    } else {
      print "backupDir='" backupDir "'" > f870
      print "restoreDir='" restoreDir "'" > f870
      print "TOUCH" ONE_TO_MAXPARALLEL "='touch -m -r'" > f870
    }
    print "set -u" > f870
  }
  SECTION_LINE > f800
  SECTION_LINE > f810
  SECTION_LINE > f820
  SECTION_LINE > f830
  SECTION_LINE > f840
  SECTION_LINE > f850
  SECTION_LINE > f860
  SECTION_LINE > f870
}
{
  if ( $2 !~ /^KEEP/ ) {
    us = $10
    gr = $11
    md = $12
    pt = $14
    ol = $16
    gsub( TRIPLETNREGEX, NLINE, pt )
    gsub( TRIPLETNREGEX, NLINE, ol )
    gsub( TRIPLETTREGEX, TAB, pt )
    gsub( TRIPLETTREGEX, TAB, ol )
    if ( "l" == $3 ) {
      gsub( TRIPLETSREGEX, SLASH, ol )
    }
    ptScp = pt
    gsub( QUOTEREGEX, QUOTEESC, us )
    gsub( QUOTEREGEX, QUOTEESC, gr )
    gsub( QUOTEREGEX, QUOTEESC, pt )
    gsub( QUOTEREGEX, QUOTEESC, ol )
    gsub( QUOTEREGEX, "'" QUOTEESCSCP "'", ptScp )
    u = "'" us "'"
    g = "'" gr "'"
    m = "'" md "'"
    b = "\"${backupDir}\"'" pt "'"
    r = "\"${restoreDir}\"'" pt "'"
    o = "\"${restoreDir}\"'" ol "'"
    bScp = "\"${backupUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
    rScp = "\"${restoreUserHostDirScp}\"" QUOTESCP "'" ptScp "'" QUOTESCP
    if ( "d" == $3 ) {
      print "${MKDIR} " r > f800
      print "${CHOWN_DIR} " u " " r > f840
      print "${CHGRP_DIR} " g " " r > f850
      print "${CHMOD_DIR} " m " " r > f860
    } else if ( "f" == $3 ) {
      if ( 1 == remoteBackup ) {
        print "${SCP" pin "} " bScp " " r > f810
        print "${STOUCH" pin "} @" $5 " " r > f870
      } else if ( 1 == remoteRestore ) {
        print "${SCP" pin "} " b " " rScp > f810
        print "${STOUCH" pin "} @" $5 " " r > f870
      } else {
        print "${CP" pin "} " b " " r > f810
        print "${TOUCH" pin "} " b " " r > f870
      }
      print "${CHOWN" pin "} " u " " r > f840
      print "${CHGRP" pin "} " g " " r > f850
      print "${CHMOD" pin "} " m " " r > f860
      if ( MAXPARALLEL <= pin ) {
        pin = 1
      } else {
        pin ++
      }
    } else if ( "l" == $3 ) {
      print "${LNSYMB} '" ol "' " r > f820
      print "${CHOWN_LNSYMB} " u " " r > f840
      print "${CHGRP_LNSYMB} " g " " r > f850
    } else if ( "h" == $3 ) {
      print "${LNHARD} " o " " r > f830
    }
  }
}
END {
  SECTION_LINE > f870
  SECTION_LINE > f860
  SECTION_LINE > f850
  SECTION_LINE > f840
  SECTION_LINE > f830
  SECTION_LINE > f820
  SECTION_LINE > f810
  SECTION_LINE > f800
  close( f870 )
  close( f860 )
  close( f850 )
  close( f840 )
  close( f830 )
  close( f820 )
  close( f810 )
  close( f800 )
}
AWKRESTORE

copyToRemoteBackup+=( "${f700}" )

if [ ${noRestore} -eq 0 ]; then

  start_progress 'Preparing shellscripts for case of restore'

  ${awk} -f "${f700}"                               \
         -v backupDir="${backupDirAwk}"             \
         -v restoreDir="${sourceDirAwk}"            \
         -v remoteBackup=${remoteBackup}            \
         -v backupUserHost="${backupUserHostAwk}"   \
         -v remoteRestore=${remoteSource}           \
         -v restoreUserHost="${sourceUserHostAwk}"  \
         -v scpExecOpt="${scpExecOptAwk}"           \
         -v cpRestoreOpt=${cpRestoreOptAwk}         \
         -v f800="${f800Awk}"                       \
         -v f810="${f810Awk}"                       \
         -v f820="${f820Awk}"                       \
         -v f830="${f830Awk}"                       \
         -v f840="${f840Awk}"                       \
         -v f850="${f850Awk}"                       \
         -v f860="${f860Awk}"                       \
         -v f870="${f870Awk}"                       \
         -v noR800Hdr=${noR800Hdr}                  \
         -v noR810Hdr=${noR810Hdr}                  \
         -v noR820Hdr=${noR820Hdr}                  \
         -v noR830Hdr=${noR830Hdr}                  \
         -v noR840Hdr=${noR840Hdr}                  \
         -v noR850Hdr=${noR850Hdr}                  \
         -v noR860Hdr=${noR860Hdr}                  \
         -v noR870Hdr=${noR870Hdr}                  \
         "${f505}"

  stop_progress

  copyToRemoteBackup+=( "${f800}" "${f810}" "${f820}" "${f830}" "${f840}" "${f850}" "${f860}" "${f870}" )

else

  files_not_prepared "${f800}" "${f810}" "${f820}" "${f830}" "${f840}" "${f850}" "${f860}" "${f870}"

  removeFromRemoteBackup+="${f800RemoteBackupScp} ${f810RemoteBackupScp} ${f820RemoteBackupScp} ${f830RemoteBackupScp} "
  removeFromRemoteBackup+="${f840RemoteBackupScp} ${f850RemoteBackupScp} ${f860RemoteBackupScp} ${f870RemoteBackupScp} "

fi

###########################################################

# Copy the prepared Exec shellscripts and other metadata to the remote side

if [ ${remoteSource} -eq 1 ]; then

  if [ ${#copyToRemoteSource[@]} -ne 0 ]; then

    progress_scp_meta '>'

    scp ${scpMetaOpt} "${copyToRemoteSource[@]}" "${sourceUserHost}:${metaDirTempScp}"

    progress_scp_meta '>'

  fi

  if [ '' != "${removeFromRemoteSource}" ]; then
    ssh ${sshOptions} "${sourceUserHost}" "rm -f ${removeFromRemoteSource}"
  fi

elif [ ${remoteBackup} -eq 1 ]; then

  progress_scp_meta '>'

  scp ${scpMetaOpt} "${copyToRemoteBackup[@]}" "${backupUserHost}:${metaDirScp}"

  progress_scp_meta '>'

  if [ '' != "${removeFromRemoteBackup}" ]; then
    ssh ${sshOptions} "${backupUserHost}" "rm -f ${removeFromRemoteBackup}"
  fi

fi

################ FLOWCHART STEPS 43 - 53 ##################

# now all preparations are done, start executing ...

if [ ${noExec} -eq 1 ]; then
  exit 0
fi

lastReply='Y'

function ask_user {
  printf '\n%s\n' "${1}"
  if [ 'Y' == "${lastReply}" ]; then
    read -p '[Y/y=Yes, S/s=do nothing and show further, other=do nothing and abort]: ' tmpVal
    tmpVal="${tmpVal/y/Y}"
    tmpVal="${tmpVal/s/S}"
    lastReply="${tmpVal}"
    tmpVal="${tmpVal/Y/S}"
    if [ 'Y' == "${lastReply}" ]; then
      printf '\n'
    fi
  else
    read -p '[S/s=do nothing and show further, other/Y/y=do nothing and abort]: ' tmpVal
    tmpVal="${tmpVal/s/S}"
    lastReply="${tmpVal}"
  fi
  if [ 'S' != "${tmpVal}" ]; then
    error_exit "User requested Zaloha to abort (file ${f999Base} was not touched)"
  fi
}

exec 4>&1

if [ -s "${f510}" ]; then

  printf '\nUNAVOIDABLE REMOVALS FROM %s\n' "${backupUserHostDirTerm}"
  printf '===========================================\n'

  ${awk} -f "${f104}" -v color=${color} "${f510}"

  if [ ${noRemove} -eq 1 ]; then
    printf '\nWARNING: Unavoidable removals prepared regardless of the --noRemove option\n'
  fi
  ask_user "Execute above listed removals from ${backupUserHostDirTerm} ?"
  if [ 'Y' == "${lastReply}" ]; then
    if [ ${remoteBackup} -eq 1 ]; then
      ssh ${sshOptions} "${backupUserHost}" "bash ${f610RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    else
      bash "${f610}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    fi
  fi
fi

printf '\nTO BE COPIED TO %s\n' "${backupUserHostDirTerm}"
printf '===========================================\n'

${awk} -f "${f104}" -v color=${color} "${f520}"

if [ -s "${f520}" ]; then
  ask_user "Execute above listed copies to ${backupUserHostDirTerm} ?"
  if [ 'Y' == "${lastReply}" ]; then
    if [ ${remoteBackup} -eq 1 ]; then
      ssh ${sshOptions} "${backupUserHost}" "bash ${f621RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      3>&1 1>&4 bash "${f622}"                                            | ${awkNoBuf} -f "${f102}" -v color=${color}
      ssh ${sshOptions} "${backupUserHost}" "bash ${f623RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    else
      bash "${f621}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
      3>&1 1>&4 bash "${f622}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      bash "${f623}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
    fi
  fi
fi

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then

  printf '\nTO BE REVERSE-COPIED TO %s\n' "${sourceUserHostDirTerm}"
  printf '===========================================\n'

  ${awk} -f "${f104}" -v color=${color} "${f530}"

  if [ -s "${f530}" ]; then
    ask_user "Execute above listed reverse-copies to ${sourceUserHostDirTerm} ?"
    if [ 'Y' == "${lastReply}" ]; then
      if [ ${remoteSource} -eq 1 ]; then
        ssh ${sshOptions} "${sourceUserHost}" "bash ${f631RemoteSourceScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
        3>&1 1>&4 bash "${f632}"                                            | ${awkNoBuf} -f "${f102}" -v color=${color}
        ssh ${sshOptions} "${sourceUserHost}" "bash ${f633RemoteSourceScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      else
        bash "${f631}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
        3>&1 1>&4 bash "${f632}" | ${awkNoBuf} -f "${f102}" -v color=${color}
        bash "${f633}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
      fi
    fi
  fi
fi

if [ ${noRemove} -eq 0 ]; then

  printf '\nTO BE REMOVED FROM %s\n' "${backupUserHostDirTerm}"
  printf '===========================================\n'

  ${awk} -f "${f104}" -v color=${color} "${f540}"

  if [ -s "${f540}" ]; then
    ask_user "Execute above listed removals from ${backupUserHostDirTerm} ?"
    if [ 'Y' == "${lastReply}" ]; then
      if [ ${remoteBackup} -eq 1 ]; then
        ssh ${sshOptions} "${backupUserHost}" "bash ${f640RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      else
        bash "${f640}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      fi
    fi
  fi
fi

if [ ${byteByByte} -eq 1 ] || [ ${sha256} -eq 1 ]; then

  printf '\nFROM COMPARING CONTENTS OF FILES: TO BE COPIED TO %s\n' "${backupUserHostDirTerm}"
  printf '===========================================\n'

  ${awk} -f "${f104}" -v color=${color} "${f550}"

  if [ -s "${f550}" ]; then
    ask_user "Execute above listed copies to ${backupUserHostDirTerm} ?"
    if [ 'Y' == "${lastReply}" ]; then
      if [ ${remoteBackup} -eq 1 ]; then
        ssh ${sshOptions} "${backupUserHost}" "bash ${f651RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
        3>&1 1>&4 bash "${f652}"                                            | ${awkNoBuf} -f "${f102}" -v color=${color}
        ssh ${sshOptions} "${backupUserHost}" "bash ${f653RemoteBackupScp}" | ${awkNoBuf} -f "${f102}" -v color=${color}
      else
        bash "${f651}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
        3>&1 1>&4 bash "${f652}" | ${awkNoBuf} -f "${f102}" -v color=${color}
        bash "${f653}"           | ${awkNoBuf} -f "${f102}" -v color=${color}
      fi
    fi
  fi
fi

exec 4>&-

# Touch the file 999_mark_executed

if [ 'Y' == "${lastReply}" ]; then
  if [ ${remoteBackup} -eq 1 ]; then
    ssh ${sshOptions} "${backupUserHost}" "bash ${f690RemoteBackupScp}"
  else
    bash "${f690}"
  fi
else
  printf '\nWarning: File %s was not touched, because not all steps were executed\n' "${f999Base}"
fi

###########################################################

# end
