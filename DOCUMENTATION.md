### OVERVIEW

<pre>
Zaloha is a small and simple directory synchronizer:

 * Zaloha is a BASH script that uses only FIND, SORT and AWK. All you need
   is the Zaloha2.sh file. This documentation is contained in Zaloha2.sh too.
 * Cyber-secure: No new binary code, no new open ports, easily reviewable.
 * Three operation modes are available: Local Mode, Remote Source Mode and
   Remote Backup Mode
 * Local Mode: Both &lt;sourceDir&gt; and &lt;backupDir&gt; are available locally
   (local HDD/SSD, flash drive, mounted Samba or NFS volume).
 * Remote Source Mode: &lt;sourceDir&gt; is on a remote source host that can be
   reached via SSH/SCP, &lt;backupDir&gt; is available locally.
 * Remote Backup Mode: &lt;sourceDir&gt; is available locally, &lt;backupDir&gt; is on a
   remote backup host that can be reached via SSH/SCP.
 * Zaloha does not lock files while copying them. No writing on either directory
   may occur while Zaloha runs.
 * Zaloha always copies whole files via the operating system's CP command
   or the SCP command (= no delta-transfer like in RSYNC).
 * Zaloha is not limited by memory (metadata is processed as CSV files,
   no limits for huge directory trees).
 * Zaloha has optional reverse-synchronization features (details below).
 * Zaloha can optionally compare the contents of files (details below).
 * Zaloha prepares scripts for case of eventual restore (details below).

To detect which files need synchronization, Zaloha compares file sizes and
modification times. It is clear that such detection is not 100% waterproof.
A waterproof solution requires comparing file contents, e.g. via "byte by byte"
comparison or via SHA-256 hashes. However, such comparing increases the
processing time by orders of magnitude. Therefore, it is not enabled by default.
Section Advanced Use of Zaloha describes two alternatives how to enable it.

Zaloha asks to confirm actions before they are executed, i.e. prepared actions
can be skipped, exceptional cases manually resolved, and Zaloha re-run.
For automatic operations, use the <b>--noExec</b> option to tell Zaloha to not ask
and to not execute the actions (but still prepare the scripts).

&lt;sourceDir&gt; and &lt;backupDir&gt; can be on different filesystem types if the
filesystem limitations are not hit. Such limitations are (e.g. in case of
ext4 -&gt; FAT): not allowed characters in filenames, filename uppercase
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

Repository: <a href="https://github.com/Fitus/Zaloha2.sh">https://github.com/Fitus/Zaloha2.sh</a>

An add-on script to create hardlink-based snapshots of the backup directory
exists, that allows to create "Time Machine"-like backup solutions:

Repository of add-on script: <a href="https://github.com/Fitus/Zaloha2_Snapshot.sh">https://github.com/Fitus/Zaloha2_Snapshot.sh</a>
</pre>


### MORE DETAILED DESCRIPTION

<pre>
The operation of Zaloha can be partitioned into five steps, in that following
actions are performed:

Exec1:  unavoidable removals from &lt;backupDir&gt; (objects of conflicting types
        which occupy needed namespace)
-----------------------------------
<b>RMDIR</b>     regular remove directory from &lt;backupDir&gt;
<b>REMOVE</b>    regular remove file from &lt;backupDir&gt;
<b>REMOVE.!</b>  remove file from &lt;backupDir&gt; which is newer than the
          last run of Zaloha
<b>REMOVE.l</b>  remove symbolic link from &lt;backupDir&gt;
<b>REMOVE.x</b>  remove other object from &lt;backupDir&gt;, x = object type (p/s/c/b/D)

Exec2:  copy files/directories to &lt;backupDir&gt; which exist only in &lt;sourceDir&gt;,
        or files which are newer in &lt;sourceDir&gt;
-----------------------------------
<b>MKDIR</b>     regular create new directory in &lt;backupDir&gt;
<b>NEW</b>       regular create new file in &lt;backupDir&gt;
<b>UPDATE</b>    regular update file in &lt;backupDir&gt;
<b>UPDATE.!</b>  update file in &lt;backupDir&gt; which is newer than the last run of Zaloha
<b>UPDATE.?</b>  update file in &lt;backupDir&gt; by a file in &lt;sourceDir&gt; which is not newer
          (or not newer by 3600 secs if option <b>--ok3600s</b> is given plus
           an eventual 2 secs FAT tolerance)
<b>unl.UP</b>    unlink file in &lt;backupDir&gt; + <b>UPDATE</b> (can be switched off via the
          <b>--noUnlink</b> option, see below)
<b>unl.UP.!</b>  unlink file in &lt;backupDir&gt; + <b>UPDATE.!</b> (can be switched off via the
          <b>--noUnlink</b> option, see below)
<b>unl.UP.?</b>  unlink file in &lt;backupDir&gt; + <b>UPDATE.?</b> (can be switched off via the
          <b>--noUnlink</b> option, see below)
<b>ATTR:ugm</b>  update only attributes in &lt;backupDir&gt; (u=user ownership,
          g=group ownership, m=mode) (optional feature, see below)

Exec3:  reverse-synchronization from &lt;backupDir&gt; to &lt;sourceDir&gt; (optional
        feature, can be activated via the <b>--revNew</b> and <b>--revUp</b> options)
-----------------------------------
<b>REV.MKDI</b>  reverse-create parent directory in &lt;sourceDir&gt; due to <b>REV.NEW</b>
<b>REV.NEW</b>   reverse-create file in &lt;sourceDir&gt; (if a standalone file in
          &lt;backupDir&gt; is newer than the last run of Zaloha)
<b>REV.UP</b>    reverse-update file in &lt;sourceDir&gt; (if the file in &lt;backupDir&gt;
          is newer than the file in &lt;sourceDir&gt;)
<b>REV.UP.!</b>  reverse-update file in &lt;sourceDir&gt; which is newer
          than the last run of Zaloha (or newer than the last run of Zaloha
          minus 3600 secs if option <b>--ok3600s</b> is given)

Exec4:  remaining removals of obsolete files/directories from &lt;backupDir&gt;
        (can be optionally switched off via the <b>--noRemove</b> option)
-----------------------------------
<b>RMDIR</b>     regular remove directory from &lt;backupDir&gt;
<b>REMOVE</b>    regular remove file from &lt;backupDir&gt;
<b>REMOVE.!</b>  remove file from &lt;backupDir&gt; which is newer than the
          last run of Zaloha
<b>REMOVE.l</b>  remove symbolic link from &lt;backupDir&gt;
<b>REMOVE.x</b>  remove other object from &lt;backupDir&gt;, x = object type (p/s/c/b/D)

Exec5:  updates resulting from optional comparing contents of files
        (optional feature, can be activated via the <b>--byteByByte</b> or
         <b>--sha256</b> options)
-----------------------------------
<b>UPDATE.b</b>  update file in &lt;backupDir&gt; because its contents is not identical
<b>unl.UP.b</b>  unlink file in &lt;backupDir&gt; + <b>UPDATE.b</b> (can be switched off via the
          <b>--noUnlink</b> option, see below)

(internal use, for completion only)
-----------------------------------
<b>OK</b>        object without needed action in &lt;sourceDir&gt; (either files or
          directories already synchronized with &lt;backupDir&gt;, or other objects
          not to be synchronized to &lt;backupDir&gt;). These records are necessary
          for preparation of shellscripts for the case of restore.
<b>OK.b</b>      file proven identical byte by byte (in CSV metadata file 555)
<b>KEEP</b>      object to be kept only in &lt;backupDir&gt;
<b>uRMDIR</b>    unavoidable <b>RMDIR</b> which goes into Exec1 (in CSV files 380 and 390)
<b>uREMOVE</b>   unavoidable <b>REMOVE</b> which goes into Exec1 (in CSV files 380 and 390)
</pre>


### INDIVIDUAL STEPS IN FULL DETAIL

<pre>
Exec1:
------
Unavoidable removals from &lt;backupDir&gt; (objects of conflicting types which occupy
needed namespace). This must be the first step, because objects of conflicting
types in &lt;backupDir&gt; would prevent synchronization (e.g. a file cannot overwrite
a directory).

Unavoidable removals are prepared regardless of the <b>--noRemove</b> option.

Exec2:
------
Files and directories which exist only in &lt;sourceDir&gt; are copied to &lt;backupDir&gt;
(action codes <b>NEW</b> and <b>MKDIR</b>).

Further, Zaloha "updates" files in &lt;backupDir&gt; (action code <b>UPDATE</b>) if files
exist under same paths in both &lt;sourceDir&gt; and &lt;backupDir&gt; and the comparisons
of file sizes and modification times result in needed synchronization of the
files. If the files in &lt;backupDir&gt; are multiply linked (hardlinked), Zaloha
removes (unlinks) them first (action code <b>unl.UP</b>), to prevent "updating"
multiply linked files, which could lead to follow-up effects. This unlinking
can be switched off via the <b>--noUnlink</b> option.

If the files differ only in attributes (u=user ownership, g=group ownership,
m=mode), and the synchronization of attributes is switched on via the <b>--pUser,</b>
<b>--pGroup</b> and <b>--pMode</b> options, then these attributes will be synchronized
(action code <b>ATTR</b>). However, this is an optional feature, because:
(1) the filesystem of &lt;backupDir&gt; might not be capable of storing these
attributes, or (2) it may be wanted that all files and directories in
&lt;backupDir&gt; are owned by the user who runs Zaloha.

Regardless of whether these attributes are synchronized or not, an eventual
restore of &lt;sourceDir&gt; from &lt;backupDir&gt; including these attributes is possible
thanks to the restore scripts which Zaloha prepares in its metadata directory
(see below).

Zaloha contains an optional feature to detect multiply linked (hardlinked) files
in &lt;sourceDir&gt;. If this feature is switched on (via the <b>--detectHLinksS</b>
option), Zaloha internally flags the second, third, etc. links to same file as
"hardlinks", and synchronizes to &lt;backupDir&gt; only the first link (the "file").
The "hardlinks" are not synchronized to &lt;backupDir&gt;, but Zaloha prepares a
restore script in its metadata directory. If this feature is switched off
(no <b>--detectHLinksS</b> option), then each link to a multiply linked file is
treated as a separate regular file.

The detection of hardlinks brings two risks: Zaloha might not detect that a file
is in fact a hardlink, or Zaloha might falsely detect a hardlink while the file
is in fact a unique file. The second risk is more severe, because the contents
of the unique file will not be synchronized to &lt;backupDir&gt; in such case.
For that reason, Zaloha contains additional checks against falsely detected
hardlinks (see code of AWKHLINKS). Generally, use this feature only after proper
testing on your filesystems. Be cautious as inode-related issues exist on some
filesystems and network-mounted filesystems.

Symbolic links in &lt;sourceDir&gt;: In the absence of the <b>--followSLinksS</b> option,
they are neither followed nor synchronized to &lt;backupDir&gt;, and Zaloha prepares
a restore script in its metadata directory. If the <b>--followSLinksS</b> option is
given, symbolic links on &lt;sourceDir&gt; are followed and the referenced files and
directories are synchronized to &lt;backupDir&gt;. See section Following Symbolic
Links for details.

Zaloha does not synchronize other types of objects in &lt;sourceDir&gt; (named pipes,
sockets, special devices, etc). These objects are considered to be part of the
operating system or parts of applications, and dedicated scripts for their
(re-)creation should exist.

It was a conscious decision to synchronize to &lt;backupDir&gt; only files and
directories and keep other objects in metadata only. This gives more freedom
in the choice of filesystem type for &lt;backupDir&gt;, because every filesystem type
is able to store files and directories, but not necessarily the other objects.

Exec3:
------
This step is optional and can be activated via the <b>--revNew</b> and <b>--revUp</b>
options.

Why is this feature useful? Imagine you use a Windows notebook while working in
the field.  At home, you have got a Linux server to that you regularly
synchronize your data. However, sometimes you work directly on the Linux server.
That work should be "reverse-synchronized" from the Linux server (&lt;backupDir&gt;)
back to the Windows notebook (&lt;sourceDir&gt;) (of course, assumed that there is no
conflict between the work on the notebook and the work on the server).

<b>REV.NEW:</b> If standalone files in &lt;backupDir&gt; are newer than the last run of
Zaloha, and the <b>--revNew</b> option is given, then Zaloha reverse-copies that
files to &lt;sourceDir&gt; (action code <b>REV.NEW</b>) including all necessary parent
directories (action code <b>REV.MKDI</b>).

<b>REV.UP:</b> If files exist under same paths in both &lt;sourceDir&gt; and &lt;backupDir&gt;,
and the files in &lt;backupDir&gt; are newer, and the <b>--revUp</b> option is given,
then Zaloha uses that files to reverse-update the older files in &lt;sourceDir&gt;
(action code <b>REV.UP</b>).

Optionally, to preserve attributes during the <b>REV.MKDI,</b> <b>REV.NEW</b> and <b>REV.UP</b>
operations: use options <b>--pRevUser,</b> <b>--pRevGroup</b> and <b>--pRevMode.</b>

If reverse-synchronization is not active: If no <b>--revNew</b> option is given,
then each standalone file in &lt;backupDir&gt; is considered obsolete (and removed,
unless the <b>--noRemove</b> option is given). If no <b>--revUp</b> option is given, then
files in &lt;sourceDir&gt; always update files in &lt;backupDir&gt; if their sizes and/or
modification times differ.

Please note that the reverse-synchronization is NOT a full bi-directional
synchronization where &lt;sourceDir&gt; and &lt;backupDir&gt; would be equivalent.
Especially, there is no <b>REV.REMOVE</b> action. It was a conscious decision to not
implement it, as any removals from &lt;sourceDir&gt; would introduce not acceptable
risks.

Reverse-synchronization to &lt;sourceDir&gt; increases the overall complexity of the
solution. Use it only in the interactive regime of Zaloha, where human oversight
and confirmation of the prepared actions are in place.
Do not use it in automatic operations.

Exec4:
------
Zaloha removes all remaining obsolete files and directories from &lt;backupDir&gt;.
This function can be switched off via the <b>--noRemove</b> option.

Why are removals from &lt;backupDir&gt; split into two steps (Exec1 and Exec4)?
The unavoidable removals must unconditionally occur first, also in Exec1 step.
But what about the remaining (avoidable) removals: Imagine a scenario when a
directory is renamed in &lt;sourceDir&gt;: If all removals were executed in Exec1,
then &lt;backupDir&gt; would transition through a state (namely between Exec1 and
Exec2) where the backup copy of the directory is already removed (under the old
name), but not yet created (under the new name). To minimize the chance for such
transient states to occur, the avoidable removals are postponed to Exec4.

Advise to this topic: In case of bigger reorganizations of &lt;sourceDir&gt;, also
e.g. in case when a directory with large contents is renamed, it is much better
to prepare a rename script (more generally speaking: a migration script) and
apply it to both &lt;sourceDir&gt; and &lt;backupDir&gt;, instead of letting Zaloha perform
massive copying followed by massive removing.

Exec5:
------
Zaloha updates files in &lt;backupDir&gt; for which the optional comparisons of their
contents revealed that they are in fact not identical (despite appearing
identical by looking at their file sizes and modification times).

The action codes are <b>UPDATE.b</b> and <b>unl.UP.b</b> (the latter is update with prior
unlinking of multiply linked target file, as described under Exec2).

Please note that these actions might indicate deeper problems like storage
corruption (or even a cyber security issue), and should be actually perceived
as surprises.

This step is optional and can be activated via the <b>--byteByByte</b> or <b>--sha256</b>
options.

Metadata directory of Zaloha
----------------------------
Zaloha creates a Metadata directory: &lt;backupDir&gt;/.Zaloha_metadata. Its location
can be changed via the <b>--metaDir</b> option.

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
script that invokes Zaloha. At the same time, use the option <b>--noLastRun</b> to
prevent Zaloha from running FIND on file 999 in the Zaloha metadata directory
to obtain the time of the last run of Zaloha.

Please note that by not keeping the Zaloha metadata directory, you sacrifice
some functionality (see <b>--noLastRun</b> option below), and you loose the CSV
metadata for an eventual analysis of problems and you loose the shellscripts
for the case of restore (especially the scripts to restore the symbolic links
and hardlinks (which are kept in metadata only)).

Temporary Metadata directory of Zaloha
--------------------------------------
In the Remote Source Mode, Zaloha needs a temporary Metadata directory on the
remote source host for copying scripts to there, executing them and obtaining
the CSV file from the FIND scan of &lt;sourceDir&gt; from there.

In the Remote Backup Mode, Zaloha performs its main metadata processing in a
temporary Metadata directory on the local (= source) host and then copies only
select metadata files to the Metadata directory on the remote (= backup) host.

The default location of the temporary Metadata directory is
&lt;sourceDir&gt;/.Zaloha_metadata_temp and can be changed via the <b>--metaDirTemp</b>
option.

Shellscripts for case of restore
--------------------------------
Zaloha prepares shellscripts for the case of restore in its Metadata directory
(scripts 800 through 860). Each type of operation is contained in a separate
shellscript, to give maximum freedom (= for each script, decide whether to apply
or to not apply). Further, each shellscript has a header part where
key variables for whole script are defined (and can be adjusted as needed).

The production of the shellscripts for the case of restore may cause increased
processing time and/or storage space consumption. It can be switched off by the
<b>--noRestore</b> option.
</pre>


### INVOCATION

<pre>
<b>Zaloha2.sh</b> <b>--sourceDir</b>=&lt;sourceDir&gt; <b>--backupDir</b>=&lt;backupDir&gt; [ other options ... ]

<b>--sourceDir</b>=&lt;sourceDir&gt; is mandatory. &lt;sourceDir&gt; must exist, otherwise Zaloha
    throws an error (except when the <b>--noDirChecks</b> option is given).
    In Remote Source mode, this is the source directory on the remote source
    host. If &lt;sourceDir&gt; is relative, then it is relative to the SSH login
    directory of the user on the remote source host.

<b>--backupDir</b>=&lt;backupDir&gt; is mandatory. &lt;backupDir&gt; must exist, otherwise Zaloha
    throws an error (except when the <b>--noDirChecks</b> option is given).
    In Remote Backup mode, this is the backup directory on the remote backup
    host. If &lt;backupDir&gt; is relative, then it is relative to the SSH login
    directory of the user on the remote backup host.

<b>--sourceUserHost</b>=&lt;sourceUserHost&gt; indicates that &lt;sourceDir&gt; resides on a remote
    source host to be reached via SSH/SCP. Format: user@host

<b>--backupUserHost</b>=&lt;backupUserHost&gt; indicates that &lt;backupDir&gt; resides on a remote
    backup host to be reached via SSH/SCP. Format: user@host

<b>--sshOptions</b>=&lt;sshOptions&gt; are additional command-line options for the
    SSH command, separated by spaces. Typical usage is explained in section
    Advanced Use of Zaloha - Remote Source and Remote Backup Modes.

<b>--scpOptions</b>=&lt;scpOptions&gt; are additional command-line options for the
    SCP command, separated by spaces. Typical usage is explained in section
    Advanced Use of Zaloha - Remote Source and Remote Backup Modes.

<b>--findSourceOps</b>=&lt;findSourceOps&gt; are additional operands for the FIND command
    that scans &lt;sourceDir&gt;, to be used to exclude files or subdirectories in
    &lt;sourceDir&gt; from synchronization to &lt;backupDir&gt;. This is a complex topic,
    described in full detail in section FIND operands to control FIND commands
    invoked by Zaloha.

    The <b>--findSourceOps</b> option can be passed in several times. In such case
    the final &lt;findSourceOps&gt; will be the concatenation of the several
    individual &lt;findSourceOps&gt; passed in with the options.

<b>--findGeneralOps</b>=&lt;findGeneralOps&gt; are additional operands for the FIND commands
    that scan both &lt;sourceDir&gt; and &lt;backupDir&gt;, to be used to exclude "Trash"
    subdirectories, independently on where they exist, from Zaloha's scope.
    This is a complex topic, described in full detail in section FIND operands
    to control FIND commands invoked by Zaloha.

    The <b>--findGeneralOps</b> option can be passed in several times. In such case
    the final &lt;findGeneralOps&gt; will be the concatenation of the several
    individual &lt;findGeneralOps&gt; passed in with the options.

<b>--findParallel</b>  ... in the Remote Source and Remote Backup Modes, run the FIND
    scans of &lt;sourceDir&gt; and &lt;backupDir&gt; in parallel. As the FIND scans run on
    different hosts in the remote modes, this will save time.

<b>--noExec</b>        ... needed if Zaloha is invoked automatically: do not ask,
    do not execute the actions, but still prepare the scripts. The prepared
    scripts then will not contain shell tracing and the "set -e" instruction.
    This means that the scripts will ignore individual failed commands and try
    to do as much work as possible, which is a behavior different from the
    interactive regime, where scripts are traced and halt on the first error.

<b>--noRemove</b>      ... do not remove files, directories and symbolic links that
    are standalone in &lt;backupDir&gt;. This option is useful when &lt;backupDir&gt; should
    hold "current" plus "historical" data whereas &lt;sourceDir&gt; holds only
    "current" data.

    Please keep in mind that if objects of conflicting types in &lt;backupDir&gt;
    prevent synchronization (e.g. a file cannot overwrite a directory),
    removals are unavoidable and will be prepared regardless of this option.
    In such case Zaloha displays a warning message in the interactive regime.
    In automatic operations, the calling process should query the CSV metadata
    file 510 to detect this case.

<b>--revNew</b>        ... enable <b>REV.NEW</b> (= if standalone file in &lt;backupDir&gt; is
                    newer than the last run of Zaloha, reverse-copy it
                    to &lt;sourceDir&gt;)

<b>--revUp</b>         ... enable <b>REV.UP</b> (= if file in &lt;backupDir&gt; is newer than
                    file in &lt;sourceDir&gt;, reverse-update the file in &lt;sourceDir&gt;)

<b>--detectHLinksS</b> ... perform hardlink detection (inode-deduplication)
                    on &lt;sourceDir&gt;

<b>--ok2s</b>          ... tolerate +/- 2 seconds differences due to FAT rounding of
                    modification times to nearest 2 seconds (special case
                    [SCC_FAT_01] explained in Special Cases section below).
                    This option is necessary only if Zaloha is unable to
                    determine the FAT file system from the FIND output
                    (column 6).

<b>--ok3600s</b>       ... additional tolerable offset of modification time differences
                    of exactly +/- 3600 seconds (special case [SCC_FAT_01]
                    explained in Special Cases section below)

<b>--byteByByte</b>    ... compare "byte by byte" files that appear identical (more
                    precisely, files for which either "no action" (<b>OK</b>) or just
                    "update of attributes" (<b>ATTR</b>) has been prepared).
                    (Explained in the Advanced Use of Zaloha section below).
                    This comparison might dramatically slow down Zaloha.
                    If additional updates of files result from this comparison,
                    they will be executed in step Exec5. This option is
                    available only in the Local Mode.

<b>--sha256</b>        ... compare contents of files via SHA-256 hashes. There is an
                    almost 100% security that files are identical if they have
                    equal sizes and SHA-256 hashes. Calculation of the hashes
                    might dramatically slow down Zaloha. If additional updates
                    of files result from this comparison, they will be executed
                    in step Exec5. This option is available in all three modes
                    (Local, Remote Source and Remote Backup).

<b>--noUnlink</b>      ... never unlink multiply linked files in &lt;backupDir&gt; before
                    writing to them

<b>--extraTouch</b>    ... use cp + touch instead of cp --preserve=timestamps
                    (special case [SCC_OTHER_01] explained in Special Cases
                    section below)

<b>--pUser</b>         ... synchronize user ownerships in &lt;backupDir&gt;
                    based on &lt;sourceDir&gt;

<b>--pGroup</b>        ... synchronize group ownerships in &lt;backupDir&gt;
                    based on &lt;sourceDir&gt;

<b>--pMode</b>         ... synchronize modes (permission bits) in &lt;backupDir&gt;
                    based on &lt;sourceDir&gt;

<b>--pRevUser</b>      ... preserve user ownerships during REV operations

<b>--pRevGroup</b>     ... preserve group ownerships during REV operations

<b>--pRevMode</b>      ... preserve modes (permission bits) during REV operations

<b>--followSLinksS</b> ... follow symbolic links on &lt;sourceDir&gt;
<b>--followSLinksB</b> ... follow symbolic links on &lt;backupDir&gt;
                    Please see section Following Symbolic Links for details.

<b>--noWarnSLinks</b>  ... suppress warnings related to symbolic links

<b>--noRestore</b>     ... do not prepare scripts for the case of restore (= saves
    processing time and disk space, see optimization note below). The scripts
    for the case of restore can still be produced ex-post by manually running
    the respective AWK program (700 file) on the source CSV file (505 file).

<b>--optimCSV</b>      ... optimize space occupied by CSV metadata files by removing
    intermediary CSV files after use (see optimization note below).
    If intermediary CSV metadata files are removed, an ex-post analysis of
    eventual problems may be impossible.

<b>--metaDir</b>=&lt;metaDir&gt; allows to place the Zaloha metadata directory to a different
    location than the default (which is &lt;backupDir&gt;/.Zaloha_metadata).
    The reasons for using this option might be:

      a) non-writable &lt;backupDir&gt; (if Zaloha is used to perform comparison only
        (i.e. with <b>--noExec</b> option))

      b) a requirement to have Zaloha metadata on a separate storage

      c) Zaloha is operated in the Local Mode, but &lt;backupDir&gt; is not available
         locally (which means that the technical integration options described
         under the section Advanced Use of Zaloha are utilized). In that case
         it is necessary to place the Metadata directory to a location
         accessible to Zaloha.

    If &lt;metaDir&gt; is placed to a different location inside of &lt;backupDir&gt;, or
    inside of &lt;sourceDir&gt; (in Local Mode), then it is necessary to explicitly
    pass a FIND expression to exclude the Metadata directory from the respective
    FIND scan via &lt;findGeneralOps&gt;.

    If Zaloha is used to synchronize multiple directories, then each such
    instance of Zaloha must have its own separate Metadata directory.

    In Remote Backup Mode, if &lt;metaDir&gt; is relative, then it is relative to the
    SSH login directory of the user on the remote backup host.

<b>--metaDirTemp</b>=&lt;metaDirTemp&gt; may be used only in the Remote Source or Remote
    Backup Modes, where Zaloha needs a temporary Metadata directory too. This
    option allows to place it to a different location than the default
    (which is &lt;sourceDir&gt;/.Zaloha_metadata_temp).

    If &lt;metaDirTemp&gt; is placed to a different location inside of &lt;sourceDir&gt;,
    then it is necessary to explicitly pass a FIND expression to exclude it
    from the respective FIND scan via &lt;findGeneralOps&gt;.

    If Zaloha is used to synchronize multiple directories in the Remote Source
    or Remote Backup Modes, then each such instance of Zaloha must have its own
    separate temporary Metadata directory.

    In Remote Source Mode, if &lt;metaDirTemp&gt; is relative, then it is relative to
    the SSH login directory of the user on the remote source host.

<b>--noDirChecks</b>   ... switch off the checks for existence of &lt;sourceDir&gt; and
    &lt;backupDir&gt;. (Explained in the Advanced Use of Zaloha section below).

<b>--noLastRun</b>     ... do not obtain time of the last run of Zaloha by running
                    FIND on file 999 in Zaloha metadata directory.
                    This makes Zaloha state-less, which might be a desired
                    property in certain situations, e.g. if you do not want to
                    keep the Zaloha metadata directory. However, this sacrifices
                    features based on the last run of Zaloha: <b>REV.NEW</b> and
                    distinction of operations on files newer than the last run
                    of Zaloha (e.g. distinction between <b>UPDATE.!</b> and <b>UPDATE</b>).

<b>--noIdentCheck</b>  ... do not check if objects on identical paths in &lt;sourceDir&gt;
                    and &lt;backupDir&gt; are identical (= identical inodes). This
                    check brings to attention cases where objects in &lt;sourceDir&gt;
                    and corresponding objects in &lt;backupDir&gt; are in reality
                    the same objects (possibly via hardlinks), which violates
                    the logic of backup. Switching off this check might be
                    necessary in some special uses of Zaloha.

<b>--noFindSource</b>  ... do not run FIND (script 210) to scan &lt;sourceDir&gt;
                    and use externally supplied CSV metadata file 310 instead
<b>--noFindBackup</b>  ... do not run FIND (script 220) to scan &lt;backupDir&gt;
                    and use externally supplied CSV metadata file 320 instead
   (Explained in the Advanced Use of Zaloha section below).

<b>--no610Hdr</b>    ... do not write header to the shellscript 610 for Exec1
<b>--no621Hdr</b>    ... do not write header to the shellscript 621 for Exec2
<b>--no622Hdr</b>    ... do not write header to the shellscript 622 for Exec2
<b>--no623Hdr</b>    ... do not write header to the shellscript 623 for Exec2
<b>--no631Hdr</b>    ... do not write header to the shellscript 631 for Exec3
<b>--no632Hdr</b>    ... do not write header to the shellscript 632 for Exec3
<b>--no633Hdr</b>    ... do not write header to the shellscript 633 for Exec3
<b>--no640Hdr</b>    ... do not write header to the shellscript 640 for Exec4
<b>--no651Hdr</b>    ... do not write header to the shellscript 651 for Exec5
<b>--no652Hdr</b>    ... do not write header to the shellscript 652 for Exec5
<b>--no653Hdr</b>    ... do not write header to the shellscript 653 for Exec5
   These options can be used only together with the <b>--noExec</b> option.
   (Explained in the Advanced Use of Zaloha section below).

<b>--noR800Hdr</b>     ... do not write header to the restore script 800
<b>--noR810Hdr</b>     ... do not write header to the restore script 810
<b>--noR820Hdr</b>     ... do not write header to the restore script 820
<b>--noR830Hdr</b>     ... do not write header to the restore script 830
<b>--noR840Hdr</b>     ... do not write header to the restore script 840
<b>--noR850Hdr</b>     ... do not write header to the restore script 850
<b>--noR860Hdr</b>     ... do not write header to the restore script 860
   (Explained in the Advanced Use of Zaloha section below).

<b>--noProgress</b>    ... suppress progress messages (less screen output). If both
                    options <b>--noExec</b> and <b>--noProgress</b> are used, Zaloha does
                    not produce any output on stdout (traditional behavior of
                    Unics tools).

<b>--color</b>         ... use color highlighting (can be used on terminals which
                    support ANSI escape codes)

<b>--mawk</b>          ... use mawk, the very fast AWK implementation based on a
                    bytecode interpreter. Without this option, awk is used,
                    which usually maps to GNU awk (but not always).
                    (Note: If you know that awk on your system maps to mawk,
                     use this option to make the mawk usage explicit, as this
                     option also turns off mawk's i/o buffering on places where
                     progress of commands is displayed, i.e. on places where
                     i/o buffering causes confusion and is unwanted).

<b>--lTest</b>         ... (do not use in real operations) support for lint-testing
                    of AWK programs

<b>--help</b>          ... show Zaloha documentation (using the LESS program) and exit

Optimization note: If Zaloha operates on directories with huge numbers of files,
especially small ones, then the size of metadata plus the size of scripts for
the case of restore may exceed the size of the files themselves. If this leads
to problems, use options <b>--noRestore</b> and <b>--optimCSV.</b>

Zaloha must be run by a user with sufficient privileges to read &lt;sourceDir&gt; and
to write and perform other required actions on &lt;backupDir&gt;. In case of the REV
actions, privileges to write and perform other required actions on &lt;sourceDir&gt;
are required as well. Zaloha does not contain any internal checks as to whether
privileges are sufficient. Failures of commands run by Zaloha must be monitored
instead.

Zaloha does not contain protection against concurrent invocations with
conflicting &lt;backupDir&gt; (and for REV also conflicting &lt;sourceDir&gt;): this is
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
</pre>


### FIND OPERANDS TO CONTROL FIND COMMANDS INVOKED BY ZALOHA

<pre>
Zaloha obtains information about the files and directories via the FIND command.

Ad FIND command itself: It must support the -printf operand, as this allows to
obtain all needed information from a directory in one scan (= one process),
which is efficient. GNU find supports the -printf operand, but some older
FIND implementations don't, so they cannot be used with Zaloha.

The FIND scans of &lt;sourceDir&gt; and &lt;backupDir&gt; can be controlled by two options:
Option <b>--findSourceOps</b> are additional operands for the FIND command that scans
&lt;sourceDir&gt; only, and the option <b>--findGeneralOps</b> are additional operands
for both FIND commands (scans of both &lt;sourceDir&gt; and &lt;backupDir&gt;).

Both options <b>--findSourceOps</b> and <b>--findGeneralOps</b> can be passed in several
times. This allows to construct the final &lt;findSourceOps&gt; and &lt;findGeneralOps&gt;
in Zaloha part-wise, e.g. expression by expression.

Difference between &lt;findSourceOps&gt; and &lt;findGeneralOps&gt;
-------------------------------------------------------
&lt;findSourceOps&gt; applies only to &lt;sourceDir&gt;. If files in &lt;sourceDir&gt; are
excluded by &lt;findSourceOps&gt; and files exist in &lt;backupDir&gt; under same paths,
then Zaloha evaluates the files in &lt;backupDir&gt; as obsolete (= removes them,
unless the <b>--noRemove</b> option is given, or eventually even attempts to
reverse-synchronize them (which leads to corner case [SCC_FIND_01]
(see the Corner Cases section))).

On the contrary, the files excluded by &lt;findGeneralOps&gt; are not visible to
Zaloha at all, neither in &lt;sourceDir&gt; nor in &lt;backupDir&gt;, so Zaloha will not
act on them.

The main use of &lt;findSourceOps&gt; is to exclude files or subdirectories in
&lt;sourceDir&gt; from synchronization to &lt;backupDir&gt;.

The main use of &lt;findGeneralOps&gt; is to exclude "Trash" subdirectories,
independently on where they exist, from Zaloha's scope.

Rules and limitations
---------------------
Both &lt;findSourceOps&gt; and &lt;findGeneralOps&gt; must consist of one or more
FIND expressions in the form of an OR-connected chain:

    expressionA -o expressionB -o ... expressionN -o

Adherence to this convention assures that Zaloha is able to correctly combine
&lt;findSourceOps&gt; with &lt;findGeneralOps&gt; and with own FIND expressions.

The OR-connected chain works so that if an earlier expression in the chain
evaluates TRUE, FIND does not evaluate following expressions, i.e. will not
evaluate the final -printf operand, so no output will be produced. In other
words, matching by any of the expressions leads to exclusion.

Further, the internal logic of Zaloha imposes the following limitations:

 * Exclusion of files by the <b>--findSourceOps</b> option: No limitations exist
   here, all expressions supported by FIND can be used (but make sure the
   exclusion applies only to files). Example: exclude all files smaller than
   1000 bytes:

    --findSourceOps='( -type f -a -size -1000c ) -o'

 * Exclusion of subdirectories by the <b>--findSourceOps</b> option: One limitation
   must be obeyed: If a subdirectory is excluded, all its contents must be
   excluded too. Why? If Zaloha sees the contents but not the subdirectory
   itself, it will prepare commands to create the contents of the subdirectory,
   but they will fail as the command to create the subdirectory itself (mkdir)
   will not be prepared. Example: exclude all subdirectories owned by user fred
   and all their contents:

    --findSourceOps='( -type d -a -user fred ) -prune -o'

   The -prune operand instructs FIND to not descend into directories matched
   by the preceding expression.

 * Exclusion of files by the <b>--findGeneralOps</b> option: As &lt;findGeneralOps&gt;
   applies to both &lt;sourceDir&gt; and &lt;backupDir&gt;, and the objects in both
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

   Note 2: As &lt;findGeneralOps&gt; act on both &lt;sourceDir&gt; and &lt;backupDir&gt; and the
   paths differ in the start point directories, the placeholder ///d/ must be
   used in the involved path patterns. This is described further below.

 * Exclusion of subdirectories by the <b>--findGeneralOps</b> option: Both above
   described limitations must be obeyed: Only expressions with -path or -name
   operands are allowed, and if subdirectories are excluded, all their contents
   must be excluded too. Notes 1 and 2 from previous bullet hold too.
   Example: exclude subdirectories lost+found wherever they exist:

    --findGeneralOps='( -type d -a -name lost+found ) -prune -o'

   If you do not care if an object is a file or a directory, you can abbreviate:

    --findGeneralOps='-name unwanted_name -prune -o'
    --findGeneralOps='-path unwanted_path -prune -o'

*** CAUTION &lt;findSourceOps&gt; AND &lt;findGeneralOps&gt;: Zaloha does not validate if
the described rules and limitations are indeed obeyed. Wrong &lt;findSourceOps&gt;
and/or &lt;findGeneralOps&gt; can break Zaloha. On the other hand, an eventual
advanced use by knowledgeable users is not prevented. Some &lt;findSourceOps&gt;
and/or &lt;findGeneralOps&gt; errors might be detected in the directories hierarchy
check in AWKCHECKER.

Troubleshooting
---------------
If FIND operands do not work as expected, debug them using FIND alone.
Let's assume, that this does not work as expected:

    --findSourceOps='( -type f -a -name *.tmp ) -o'

The FIND command to debug this is:

    find &lt;sourceDir&gt; '(' -type f -a -name '*.tmp' ')' -o -printf 'path: %P\n'

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
&lt;findSourceOps&gt; and &lt;findGeneralOps&gt; are passed into Zaloha as single strings.
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
If expressions with the "-path" operand are used in &lt;findSourceOps&gt;, the
placeholder ///d/ should be used in place of &lt;sourceDir&gt;/ in their path
patterns.

If expressions with the "-path" operand are used in &lt;findGeneralOps&gt;, the
placeholder ///d/ must (not should) be used in place of &lt;sourceDir&gt;/ and
&lt;backupDir&gt;/ in their path patterns, unless, perhaps, the &lt;sourceDir&gt; and
&lt;backupDir&gt; parts of the paths are matched by a FIND wildcard.

Zaloha will replace ///d/ by the start point directory that is passed to FIND
in the given scan, with eventual FIND pattern special characters properly
escaped (which relieves you from doing the same by yourself).

Example: exclude &lt;sourceDir&gt;/.git

    --findSourceOps="-path ///d/.git -prune -o"

Internally defined default for &lt;findGeneralOps&gt;
-----------------------------------------------
&lt;findGeneralOps&gt; has an internally defined default, used to exclude:

    &lt;sourceDir or backupDir&gt;/$RECYCLE.BIN
      ... Windows Recycle Bin (assumed to exist directly under &lt;sourceDir&gt; or
          &lt;backupDir&gt;)

    &lt;sourceDir or backupDir&gt;/.Trash_&lt;number&gt;*
      ... Linux Trash (assumed to exist directly under &lt;sourceDir&gt; or
          &lt;backupDir&gt;)

    &lt;sourceDir or backupDir&gt;/lost+found
      ... Linux lost + found filesystem fragments (assumed to exist directly
          under &lt;sourceDir&gt; or &lt;backupDir&gt;)

To replace this internal default with own &lt;findGeneralOps&gt;:

    --findGeneralOps=&lt;your replacement&gt;

To switch off this internal default:

    --findGeneralOps=

To extend (= combine, not replace) the internal default by own extension (note
the plus (+) sign):

    --findGeneralOps=+&lt;your extension&gt;

If several <b>--findGeneralOps</b> options are passed in, the plus (+) sign mentioned
above should be passed in only with the first instance, not with the second,
third (and so on) instances.

Known traps and problems
------------------------
Beware of matching the start point directories &lt;sourceDir&gt; or &lt;backupDir&gt; 
themselves by the expressions and patterns.

In some FIND versions, the name patterns starting with the asterisk (*)
wildcard do not match objects whose names start with a dot (.).
</pre>


### FOLLOWING SYMBOLIC LINKS

<pre>
Technically, the <b>--followSLinksS</b> and/or <b>--followSLinksB</b> options in Zaloha
"just" pass the -L option to the FIND commands that scan &lt;sourceDir&gt; and/or
&lt;backupDir&gt;. However, it takes a fair amount of text to describe the impacts:

If FIND is invoked with the -L option, it returns information about the objects
the symbolic links point to rather than the symbolic links themselves (unless
the symbolic links are broken). Moreover, if the symbolic links point to
directories, the FIND scans continue in that directories as if they were
subdirectories (= symbolic links are followed).

In other words: If the directory structure of &lt;sourceDir&gt; is spanned by symbolic
links and symbolic links are followed due to the <b>--followSLinksS</b> option,
the FIND output will contain the whole structure spanned by the symbolic links,
BUT will not give any clue that FIND was going over the symbolic links.

The same sentence holds for &lt;backupDir&gt; and the <b>--followSLinksB</b> option.

Corollary 1: Independently on whether &lt;sourceDir&gt; is a plain directory structure
or spanned by symbolic links, Zaloha will create a plain directory structure
in &lt;backupDir&gt;. If the structure of &lt;backupDir&gt; should by spanned by symbolic
links too (not necessarily identically to &lt;sourceDir&gt;), then the symbolic links
and the referenced objects must be prepared in advance and the <b>--followSLinksB</b>
option must be given to follow symbolic links on &lt;backupDir&gt; (otherwise Zaloha
would remove the prepared symbolic links on &lt;backupDir&gt; and create real files
and directories in place of them).

Corollary 2: The restore scripts are not aware of the symbolic links that
spanned the original structure. They will restore a plain directory structure.
Again, if the structure of the restored directory should be spanned by symbolic
links, then the symbolic links and the referenced objects must be prepared
in advance. Please note that if the option <b>--followSLinksS</b> is given, the file
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

Corner case removal operations: Eventual removal operations on places where the
structure is held together by the symbolic links are problematic. Zaloha will
prepare the <b>REMOVE</b> (rm -f) or <b>RMDIR</b> (rmdir) operations due to the objects having
been reported to it as files or directories. However, if the objects are in
reality symbolic links, "rm -f" removes the symbolic links themselves, not the
referenced objects, and "rmdir" fails with the "Not a directory" error.

Corner case loops: Loops can occur if symbolic links are in play. Zaloha can
only rely on the FIND command to handle them (= prevent running forever).
GNU find, for example, contains an internal mechanism to handle loops.

Technical note for the case when the start point directories themselves are
symbolic links: Zaloha passes all start point directories to FIND with trailing
slashes, which instructs FIND to follow them if they are symbolic links.
</pre>


### TESTING, DEPLOYMENT, INTEGRATION

<pre>
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

Verify that all your programs that write to &lt;sourceDir&gt; change modification
times of the files written, so that Zaloha does not miss changed files.

Simulate the loss of &lt;sourceDir&gt; and perform test of the recovery scenario using
the recovery scripts prepared by Zaloha.

Automatic operations
--------------------
Additional care must be taken when using Zaloha in automatic operations
(<b>--noExec</b> option):

Exit status and standard error of Zaloha and of the scripts prepared by Zaloha
must be monitored by a monitoring system used within your IT landscape.
Nonzero exit status and writes to standard error must be brought to attention
and investigated. If Zaloha itself fails, the process must be aborted.
The scripts prepared under the <b>--noExec</b> option do not halt on the first error,
also their zero exit status does not imply that there were no failed
individual commands.

Implement sanity checks to avoid data disasters like synchronizing &lt;sourceDir&gt;
to &lt;backupDir&gt; in the moment when &lt;sourceDir&gt; is unmounted, which would lead
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
</pre>


### SPECIAL AND CORNER CASES

<pre>
Cases related to the use of FIND
--------------------------------
Ideally, the FIND scans return data about all objects in the directories.
However, the options <b>--findSourceOps</b> and <b>--findGeneralOps</b> may cause parts
of the reality to be hidden (masked) from Zaloha, leading to these cases:

[SCC_FIND_01]
Corner case <b>--revNew</b> with <b>--findSourceOps:</b> If files exist under same paths
in both &lt;sourceDir&gt; and &lt;backupDir&gt;, and in &lt;sourceDir&gt; the files are masked by
&lt;findSourceOps&gt; and in &lt;backupDir&gt; the corresponding files are newer than the
last run of Zaloha, Zaloha prepares <b>REV.NEW</b> actions (that are wrong). This is
an error which Zaloha is unable to detect. Hence, the shellscripts for Exec3
contain REV_EXISTS checks that throw errors in such situations.

[SCC_FIND_02]
Corner case <b>RMDIR</b> with <b>--findGeneralOps:</b> If objects exist under a given
subdirectory of &lt;backupDir&gt; and all of them are masked by &lt;findGeneralOps&gt;,
and Zaloha prepares a <b>RMDIR</b> on that subdirectory, then that <b>RMDIR</b> fails with
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
   <b>--ok2s</b> option.

 * In some situations, offsets of exactly +/- 1 hour (+/- 3600 seconds)
   must be tolerated as well. Typically, this is necessary when one of the
   directories is on a filesystem type that stores modification times
   in local time instead of in universal time (e.g. FAT), and the OS is not
   able, for some reason, to correctly adjust for daylight saving time while
   converting the local time.

 * The additional tolerable offsets of +/- 3600 seconds can be activated via the
   <b>--ok3600s</b> option. They are assumed to exist between files in &lt;sourceDir&gt;
   and files in &lt;backupDir&gt;, but not between files in &lt;backupDir&gt; and the
   999 file in &lt;metaDir&gt; (from which the time of the last run of Zaloha is
   obtained). This last note is relevant especially if &lt;metaDir&gt; is located
   outside of &lt;backupDir&gt; (which is achievable via the <b>--metaDir</b> option).

[SCC_FAT_02]
Corner case <b>REV.UP</b> with <b>--ok3600s:</b> The <b>--ok3600s</b> option makes it harder
to determine which file is newer (decision <b>UPDATE</b> vs <b>REV.UP</b>). The implemented
solution for that case is that for <b>REV.UP,</b> the &lt;backupDir&gt; file must be newer
by more than 3600 seconds (plus an eventual 2 secs FAT tolerance).

[SCC_FAT_03]
Corner case FAT uppercase conversions: Explained by following example:

The source directory is on a Linux ext4 filesystem and contains the files
SOUBOR.TXT, SOUBOR.txt, soubor.TXT and soubor.txt in one of the subdirectories.
The backup directory is on a FAT-formatted USB flash drive. The synchronization
executes without visible problems, but in the backup directory, only SOUBOR.TXT
exists after the synchronization.

What happened is that the OS/filesystem re-directed all four copy operations
into SOUBOR.TXT. Also, after three overwrites, the backup of only one of the
four source files exists. Zaloha detects this situation on next synchronization
and prepares new copy commands, but they again hit the same problem.

The only effective solution seems to be the renaming of the source files to
avoid this type of name conflict.

Last note: A similar phenomenon has been observed in the Cygwin environment
running on Windows/ntfs too.

Cases related to hardlinked files
---------------------------------
[SCC_HLINK_01]
Corner case <b>--detectHLinksS</b> with new link(s) to same file added or removed:
The assignment of what link will be kept as "file" (f) and what links will be
tagged as "hardlinks" (h) in CSV metadata after AWKHLINKS may change, leading
to <b>NEW</b> and <b>REMOVE</b> actions.

[SCC_HLINK_02]
Corner case <b>REV.UP</b> with <b>--detectHLinksS:</b> Zaloha supports reverse-update of
only the first links in &lt;sourceDir&gt; (the ones that stay tagged as "files" (f)
in CSV metadata after AWKHLINKS). See also [SCC_CONFL_02].

[SCC_HLINK_03]
Corner case <b>UPDATE</b> or <b>REV.UP</b> with hardlinked files: Updating a multiply linked
(hardlinked) file means that the new contents will appear under all other links,
and that may lead to follow-up effects.

[SCC_HLINK_04]
Corner case update of attributes with hardlinked files: Updated attributes on a
multiply linked (hardlinked) file will (with exceptions on some filesystem
types) appear under all other links, and that may lead to follow-up effects.

[SCC_HLINK_05]
Corner case if same directory is passed in as &lt;sourceDir&gt; and &lt;backupDir&gt;:
Zaloha will issue a warning about identical objects. No actions will be prepared
due to both directories being identical, except when the directory contains
multiply-linked (hardlinked) files and the <b>--detectHLinksS</b> option is given.
In that case, Zaloha will prepare removals of the second, third, etc. links to
same files. This interesting side-effect (or new use case) is explained as
follows: Zaloha will perform hardlink detection on &lt;sourceDir&gt; and for the
detected hardlinks (h) it prepares removals of the corresponding files in
&lt;backupDir&gt;, which is the same directory. The hardlinks can be restored by
restore script 830_restore_hardlinks.sh.

Cases related to conflicting object type combinations
-----------------------------------------------------
[SCC_CONFL_01]
Corner case <b>REV.NEW</b> with namespace on &lt;sourceDir&gt; needed for <b>REV.MKDI</b> or <b>REV.NEW</b>
actions is occupied by objects of conflicting types: The files in &lt;backupDir&gt;
will not be reverse-copied to &lt;sourceDir&gt;, but removed. As these files must be
newer than the last run of Zaloha, the actions will be <b>REMOVE.!.</b>

[SCC_CONFL_02]
Corner case <b>--detectHLinksS</b> with objects in &lt;backupDir&gt; under same paths as
the seconds, third etc. hardlinks in &lt;sourceDir&gt; (the ones that will be tagged
as "hardlinks" (h) in CSV metadata after AWKHLINKS): The objects in &lt;backupDir&gt;
will be (unavoidably) removed to avoid misleading situations in that for a
hardlinked file in &lt;sourceDir&gt;, &lt;backupDir&gt; would contain a different object
(or eventually even a different file) under same path.

[SCC_CONFL_03]
Corner case objects in &lt;backupDir&gt; under same paths as symbolic links in
&lt;sourceDir&gt;: The objects in &lt;backupDir&gt; will be (unavoidably) removed to avoid
misleading situations in that for a symbolic link in &lt;sourceDir&gt; that points
to an object, &lt;backupDir&gt; would contain a different object under same path.
The only exception is when the objects in &lt;backupDir&gt; are symbolic links too,
in which case they will be kept (but not changed). Please see section
Following Symbolic Links on when symbolic links are not reported as
symbolic links by FIND.

[SCC_CONFL_04]
Corner case objects in &lt;backupDir&gt; under same paths as other objects (p/s/c/b/D)
in &lt;sourceDir&gt;: The objects in &lt;backupDir&gt; will be (unavoidably) removed except
when they are other objects (p/s/c/b/D) too, in which case they will be kept
(but not changed).

Other cases
-----------
[SCC_OTHER_01]
In some situations (e.g. Linux Samba + Linux Samba client),
cp --preserve=timestamps does not preserve modification timestamps (unless on
empty files). In that case, Zaloha should be instructed (via the <b>--extraTouch</b>
option) to use subsequent extra TOUCH commands instead, which is a more robust
solution. In the scripts for case of restore, extra TOUCH commands are used
unconditionally.

[SCC_OTHER_02]
Corner case if the Metadata directory is in its default location (= no option
<b>--metaDir</b> is given) and &lt;sourceDir&gt;/.Zaloha_metadata exists as well (which
may be the case in chained backups (= backups of backups)): It will be excluded.
If a backup of that directory is needed as well, it should be solved separately.
Hint: if the secondary backup starts one directory higher, then this exclusion
will not occur anymore.

Why be concerned about backups of the Metadata directory of the primary backup:
keep in mind that Zaloha synchronizes to &lt;backupDir&gt; only files and directories
and keeps other objects in metadata (and the restore scripts) only.

[SCC_OTHER_03]
It is possible (but not recommended) for &lt;backupDir&gt; to be a subdirectory of
&lt;sourceDir&gt; and vice versa. In such cases, FIND expressions to avoid recursive
copying must be passed in via &lt;findGeneralOps&gt;.
</pre>


### HOW ZALOHA WORKS INTERNALLY

<pre>
Handling and checking of input parameters should be self-explanatory.

The actual program logic is embodied in AWK programs, which are contained in
Zaloha as "here documents".

The AWK program AWKPARSER parses the FIND operands assembled from
&lt;findSourceOps&gt; and &lt;findGeneralOps&gt; and constructs the FIND commands.
The outputs of running these FIND commands are tab-separated CSV metadata files
that contain all information needed for following steps. These CSV metadata
files, however, must first be processed by AWKCLEANER to handle (escape)
eventual tabs and newlines in filenames + perform other required preparations.

The cleaned CSV metadata files are then checked by AWKCHECKER for unexpected
deviations (in which case an error is thrown and the processing stops).

The next (optional) step is to detect hardlinks: the CSV metadata file from
&lt;sourceDir&gt; will be sorted by device numbers + inode numbers. This means that
multiply-linked files will be in adjacent records. The AWK program AWKHLINKS
evaluates this situation: The type of the first link will be kept as "file" (f),
the types of the other links will be changed to "hardlinks" (h).

Then comes the core function of Zaloha. The CSV metadata files from &lt;sourceDir&gt;
and &lt;backupDir&gt; will be united and sorted by file's paths and the Source/Backup
indicators. This means that objects existing in both directories will be in
adjacent records, with the &lt;backupDir&gt; record coming first. The AWK program
AWKDIFF evaluates this situation (as well as records from objects existing in
only one of the directories), and writes target state of synchronized
directories with actions to reach that target state.

The output of AWKDIFF is then sorted by file's paths in reverse order (so that
parent directories come after their children) and post-processed by AWKPOSTPROC.
AWKPOSTPROC modifies actions on parent directories of files to <b>REV.NEW</b> and
objects to <b>KEEP</b> only in &lt;backupDir&gt;.

The remaining code uses the produced data to perform actual work, and should be
self-explanatory.

An interactive JavaScript flowchart exists that explains the internal processing
within Zaloha in a graphical and intuitive manner.

  Interactive JavaScript flowchart: <a href="https://fitus.github.io/flowchart.html">https://fitus.github.io/flowchart.html</a>

Understanding AWKDIFF is the key to understanding of whole Zaloha. An important
hint to AWKDIFF is that there can be five types of filesystem objects in
&lt;sourceDir&gt; and four types of filesystem objects in &lt;backupDir&gt;. At any given
path, each type in &lt;sourceDir&gt; can meet each type in &lt;backupDir&gt;, plus each
type can be standalone in either &lt;sourceDir&gt; or &lt;backupDir&gt;. Mathematically,
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

  Note 1: Hardlinks (h) cannot occur in &lt;backupDir&gt;, because the type "h" is not
  reported by FIND but determined by AWKHLINKS that can operate only on
  &lt;sourceDir&gt;.

  Note 2: Please see section Following Symbolic Links on when symbolic links
  are not reported as symbolic links by FIND.

The AWKDIFF code is commented on key places to make orientation easier.
A good case to begin with is case 6 (file in &lt;sourceDir&gt;, file in &lt;backupDir&gt;),
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
in &lt;sourceDir&gt; and other object in &lt;backupDir&gt;: File 505 then contains an
<b>OK</b> record for the former and a <b>KEEP</b> record for the latter, both with the
same file's path (column 14).
</pre>


### TECHNIQUES USED BY ZALOHA TO HANDLE WEIRD CHARACTERS IN FILENAMES

<pre>
Handling of "weird" characters in filenames was a special focus during
development of Zaloha. Actually, it was an exercise of how far can be gone with
a shellscript alone, without reverting to a C program. Tested were:
!"#$%&amp;'()*+,-.:;&lt;=&gt;?@[\]^`{|}~, spaces, tabs, newlines, alert (bell) and
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
internal escape logic from the outside. The only exception are &lt;findSourceOps&gt;
and &lt;findGeneralOps&gt;, which may contain the ///d/ placeholder.

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
  Case 2: given dir and dir&lt;tab&gt;ectory, they would be sort ordered:
          dir/!subdir1, dir///tectory, dir/subdir2.

Zaloha does not contain any explicit handling of national characters in
filenames (= characters beyond ASCII 127). It is assumed that the commands used
by Zaloha handle them transparently (which should be tested on environments
where this topic is relevant). &lt;sourceDir&gt; and &lt;backupDir&gt; must use the same
code page for national characters in filenames, because Zaloha does not contain
any code page conversions.
</pre>


### ADVANCED USE OF ZALOHA - REMOTE SOURCE AND REMOTE BACKUP MODES

<pre>
Remote Source Mode
------------------
In the Remote Source Mode, &lt;sourceDir&gt; is on a remote source host that can be
reached via SSH/SCP, and &lt;backupDir&gt; is available locally. This mode is
activated by the <b>--sourceUserHost</b> option.

The FIND scan of &lt;sourceDir&gt; is run on the remote side in an SSH session, the
FIND scan of &lt;backupDir&gt; runs locally. The subsequent sorts + AWK processing
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
In the Remote Backup Mode, &lt;sourceDir&gt; is available locally, and &lt;backupDir&gt; is
on a remote backup host that can be reached via SSH/SCP. This mode is activated
by the <b>--backupUserHost</b> option.

The FIND scan of &lt;sourceDir&gt; runs locally, the FIND scan of &lt;backupDir&gt; is run
on the remote side in an SSH session. The subsequent sorts + AWK processing
steps occur locally. The Exec1/2/3/4/5 steps are then executed as follows:

Exec1: The shellscript 610 is run on the remote side "in one batch", because it
contains only <b>RMDIR</b> and <b>REMOVE</b> operations to be executed on &lt;backupDir&gt;.

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
Running multiple operations on the remote side via SSH "in one batch" has
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
           &lt;remoteUserHost&gt;

To instruct the SSH and SCP commands invoked by Zaloha to use the SSH master
connection, use the options <b>--sshOptions</b> and <b>--scpOptions:</b>

  <b>--sshOptions</b>='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'
  <b>--scpOptions</b>='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'

After use, the SSH master connection should be terminated as follows:

  ssh -O exit -o ControlPath='~/.ssh/cm-%r@%h:%p' &lt;remoteUserHost&gt;

Windows / Cygwin notes:
-----------------------
Make sure you use the Cygwin's version of OpenSSH, not the Windows' version.

As of OpenSSH_8.3p1, the SSH connection multiplexing on Cygwin (still) doesn't
seem to work, not even in the Proxy Multiplexing mode (-O proxy).

To avoid repeated entering of passwords, set up SSH Public Key authentication.

Other SSH/SCP-related remarks:
------------------------------
The remote source or backup directory &lt;sourceDir&gt; or &lt;backupDir&gt;, if relative,
is relative to the SSH login directory of the user on the remote host.

To use a different port, use also the options <b>--sshOptions</b> and <b>--scpOptions</b>
to pass the options "-p &lt;port&gt;" to SSH and "-P &lt;port&gt;" to SCP.

The SCP commands that copy from remote to local may require the "-T" option
to disable the (broken?) SCP-internal check that results in false findings like
"filename does not match request" or "invalid brace pattern". Use <b>--scpOptions</b>
to pass the "-T" option to SCP.

The individual option words in &lt;sshOptions&gt; and &lt;scpOptions&gt; are separated by
spaces. Neither SSH nor SCP allows/requires words in their command-line options
that would themselves contain spaces or metacharacters that would undergo
additional shell expansions, also Zaloha does not contain any sophisticated
handling of &lt;sshOptions&gt; and &lt;scpOptions&gt;.

Zaloha always invokes the SCP command with the "-p" option (this is hardcoded).
This option instructs SCP to preserve timestamps during copying, but modes
(permission bits) are preserved too, which is an (unavoidable) side effect.

Eventual "at" signs (@) and colons (:) contained in directory names should not
cause misinterpretations as users and hosts by SCP, because Zaloha prepends
relative paths by "./" and SCP does not interpret "at" signs (@) and colons (:)
after first slash in file/directory names.
</pre>


### ADVANCED USE OF ZALOHA - COMPARING CONTENTS OF FILES

<pre>
First, let's make it clear that comparing contents of files will increase the
runtime dramatically, because instead of reading just the directory data,
the files themselves must be read.

ALTERNATIVE 1: option <b>--byteByByte</b> (suitable if both filesystems are local)

Option <b>--byteByByte</b> forces Zaloha to compare "byte by byte" files that appear
identical (more precisely, files for which either "no action" (<b>OK</b>) or just
"update of attributes" (<b>ATTR</b>) has been prepared). If additional updates of files
result from this comparison, they will be executed in step Exec5.

ALTERNATIVE 2: option <b>--sha256</b> (compare contents of files via SHA-256 hashes)

There is an almost 100% security that files are identical if they have equal
sizes and SHA-256 hashes. The <b>--sha256</b> option instructs Zaloha to prepare
FIND expressions that, besides collecting the usual metadata via the -printf
operand, cause SHA256SUM to be invoked on each file to calculate the SHA-256
hash. These calculated hashes are contained in extra records in files 310 and
320, and AWKCLEANER merges them into the regular records in the cleaned files
330 and 340 (the SHA-256 hashes go into column 13).

If additional updates of files result from comparisons of SHA-256 hashes,
they will be executed in step Exec5 (same principle as for the <b>--byteByByte</b>
option).

Comparing contents of files via the SHA-256 hashes should be used when the
source and backup directories reside on different hosts and the FIND scans are
executed on those hosts (in Remote Source and Remote Backup Modes): The SHA-256
hashes will then be calculated on each host locally and the comparisons of file
contents require just the hashes to be transferred over the network, not the
files themselves.
</pre>


### ADVANCED USE OF ZALOHA - COPYING FILES IN PARALLEL

<pre>
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
wrapper script should invoke Zaloha with the <b>--noExec</b> and <b>--no622Hdr</b>
options, also Zaloha prepares the 622 script without header (i.e. body only).
The wrapper script should prepare the 8 different headers and use them
with the header-less 622 script (of which only one copy is needed then).
</pre>


### ADVANCED USE OF ZALOHA - TECHNICAL INTEGRATION OPTIONS

<pre>
Zaloha contains several options to make technical integrations easy. In the
extreme case, Zaloha can be used as a mere "difference engine" which takes
the FIND data from &lt;sourceDir&gt; and/or &lt;backupDir&gt; as inputs and produces the
CSV metadata and the Exec1/2/3/4/5 scripts as outputs.

First useful option is <b>--noDirChecks:</b> This switches off the checks for
existence of &lt;sourceDir&gt; and &lt;backupDir&gt;.

In Local Mode, if &lt;backupDir&gt; is not available locally, it is necessary to use
the <b>--metaDir</b> option to place the Zaloha metadata directory to a location
accessible to Zaloha.

Next useful options are <b>--noFindSource</b> and/or <b>--noFindBackup:</b> They instruct
Zaloha to not run FIND on &lt;sourceDir&gt; and/or &lt;backupDir&gt;, but use externally
supplied CSV metadata files 310 and/or 320 instead. This means that these files
must be produced externally and downloaded to the Zaloha metadata directory
before invoking Zaloha. These files must, of course, have the same names and
contents as the CSV metadata files that would otherwise be produced by the
scripts 210 and/or 220.

The <b>--noFindSource</b> and/or <b>--noFindBackup</b> options are also useful when
network-mounted directories are available locally, but running FIND on them is
slow. Running the FINDs directly on the respective file servers in SSH sessions
should be much quicker.

The <b>--noExec</b> option can be used to prevent execution of the Exec1/2/3/4/5
scripts by Zaloha itself.

Last set of useful options are <b>--no610Hdr</b> through <b>--no653Hdr.</b> They instruct
Zaloha to produce header-less Exec1/2/3/4/5 scripts (i.e. bodies only).
The headers normally contain definitions used in the bodies of the scripts.
Header-less scripts can be easily used with alternative headers that contain
different definitions. This gives much flexibility:

The "command variables" can be assigned to different commands (e.g. cp -&gt; scp).
Own shell functions can be defined and assigned to the "command variables".
This makes more elaborate processing possible, as well as calling commands that
have different order of command line arguments. Next, the "directory variables"
sourceDir and backupDir can be assigned to empty strings, thus causing the paths
passed to the commands to be not prefixed by &lt;sourceDir&gt; and &lt;backupDir&gt;.
</pre>


### CYBER SECURITY TOPICS

<pre>
Standard security practices should be followed on environments exposed to
potential attackers: Potential attackers should not be allowed to modify the
command line that invokes Zaloha, the PATH variable, BASH init scripts or other
items that may influence how Zaloha works and invokes operating system commands.

Further, the following security threats arise from backup of a directory that is
writable by a potential attacker:

Backup media overflow attack via hardlinks
------------------------------------------
The attacker might create a huge file in his home directory and hardlink it
many thousands times, hoping that the backup program writes all copies to
the backup media ...

Mitigation with Zaloha: perform hardlink detection (use the <b>--detectHLinksS</b>
option)

Backup media overflow attack via symbolic links
-----------------------------------------------
The attacker might create many symbolic links pointing to directories with huge
contents outside of his home directory, hoping that the backup program writes
all linked contents to the backup media ...

Mitigation with Zaloha: do not follow symbolic links on &lt;sourceDir&gt; (do not use
                        the <b>--followSLinksS</b> option)

Unauthorized access via symbolic links
--------------------------------------
The attacker might create symbolic links to locations to which he has no access,
hoping that within the restore process (which he might explicitly request for
this purpose) the linked contents will be restored to his home directory ...

Mitigation with Zaloha: do not follow symbolic links on &lt;sourceDir&gt; (do not use
                        the <b>--followSLinksS</b> option)

Privilege escalation attacks
----------------------------
The attacker might create a rogue executable program in his home directory with
the SetUID and/or SetGID bits set, hoping that within the backup process (or
within the restore process, which he might explicitly request for this purpose),
the user/group ownership of his rogue program changes to a user/group with
higher privileges (ideally root), the SetUID and/or SetGID bits will be restored
and he will have access to this program ...

Mitigation with Zaloha: Prevent this scenario. Be specially careful with options
                        <b>--pMode</b> and <b>--pRevMode</b> and with the restore script
                        860_restore_mode.sh

Shell code injection attacks
----------------------------
The attacker might create a file in his home directory with a name that is
actually a rogue shell code (e.g. '; rm -Rf ..'), hoping that the shell code
will, due to some program flaw, be executed by a user with higher privileges.

Mitigation with Zaloha: currently not aware of such vulnerability within Zaloha.
                        If found, please open a high priority issue on GitHub.
</pre>
