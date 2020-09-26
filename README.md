# Zaloha2.sh

Zaloha2.sh is the next step in development of [Zaloha.sh](https://github.com/Fitus/Zaloha.sh), the small and simple directory synchronizer (a BASH script).

## Why a new repository and program name?

 * Some design changes break backward compatibility (see full list of changes below).
 * To keep the original [Zaloha.sh](https://github.com/Fitus/Zaloha.sh) intact for the conservative user.

## Documentation

Full documentation is available both [online](DOCUMENTATION.md) as well as inside of Zaloha2.sh.

For all other documentation and explanatory items (Article, Flowchart, Screenshot, Simple Demo, Performance Data) refer to the original
[Zaloha.sh](https://github.com/Fitus/Zaloha.sh) repository.

## Main new feature: The Remote Backup Mode

The Remote Backup Mode is activated by the option **--backupUserHost**.

### The Remote Backup Mode explained in eight sentences

 * The FIND scan of the source directory occurs locally (no change against Zaloha.sh).
 * The script for FIND scan of the backup directory (file 220) is prepared locally.
 * The script is then copied to the remote backup host via SCP and executed via SSH.
 * The obtained CSV metadata (file 320) is copied back from the remote backup host via SCP.
 * The CSV metadata is compared by a sequence of sorts and AWK processing steps (occurs locally).
 * The results (= prepared synchronization actions) are presented to the user for confirmation.
 * If the user confirms, the synchronization actions are executed (via SSH and SCP).
 * A non-interactive regime is available as well.

### How to compare the contents of files in Remote Backup Mode

The option **--byteByByte** cannot be used in Remote Backup Mode, because the CMP command needs local access to both compared files.

For the Remote Backup Mode, a new option **--sha256** has been introduced. This option causes both FIND scans to additionally
invoke SHA256SUM on each encountered file. Note that the SHA-256 hashes of the source files are calculated locally and the
SHA-256 hashes of the backup files are calculated on the remote backup host. Also no contents of files are transferred
over the network, just the SHA-256 hashes. The SHA-256 hashes are then compared locally to detect files that appear identical
but their contents differ.

## Usage Example of the Remote Backup Mode

```bash
# Establish the SSH master connection
ssh -nNf -o ControlMaster=yes -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@backuphost'

# Run Zaloha2.sh
./Zaloha2.sh --sourceDir="test_source_local"     \
             --backupDir="test_backup_remote"    \
             --backupUserHost='user@backuphost'  \
             --sshOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'     \
             --scpOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p -T'  \
             [other options, see docu]

# Terminate the SSH master connection
ssh -O exit -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@backuphost'
```

## Obtain Zaloha2.sh

The simplest way: Under the green button "<b>Code</b>" above, choose "<b>Download ZIP</b>".
From the downloaded ZIP archive, extract Zaloha2.sh and make it executable (<b>chmod u+x Zaloha2.sh</b>).

## Add-on script Zaloha2_Snapshot.sh

The script for hardlink-based snapshots has been adapted to Zaloha2.sh: [Zaloha2_Snapshot](https://github.com/Fitus/Zaloha2_Snapshot.sh).
This allows to create **Time&nbsp;Machine**-like backup solutions.

## Full list of changes and new features of Zaloha2.sh

Zaloha.sh | Zaloha2.sh
--------- | ----------
&nbsp; | New option **--backupUserHost** to activate the Remote Backup Mode via SSH/SCP
&nbsp; | New option **--sshOptions** to pass additional command-line options to SSH in the Remote Backup Mode
&nbsp; | New option **--scpOptions** to pass additional command-line options to SCP in the Remote Backup Mode
Option **--metaDir** | In Remote Backup Mode: allows to place the Zaloha metadata directory on the remote backup host to a different location than the default.
&nbsp; | New option **--metaDirTemp**: In the Remote Backup Mode, Zaloha needs a local temporary Metadata directory too. This option allows to place it to a different location than the default.
Shellscript 610 | In Remote Backup Mode: executed on the remote side
Shellscript 620 | In Remote Backup Mode: split to 621 (pre-copy on the remote side), 622 (SCP commands locally), 623 (post-copy on the remote side)
Shellscript 630 | In Remote Backup Mode: contains SCP commands instead of CP commands
Shellscript 640 | In Remote Backup Mode: executed on the remote side
Shellscript 650 | In Remote Backup Mode: split to 651 (pre-copy on the remote side), 652 (SCP commands locally), 653 (post-copy on the remote side)
Restore script 810 | In Remote Backup Mode: contains SCP commands instead of CP commands
&nbsp; | New option **--sha256** for comparing the contents of files via SHA-256 hashes
CSV data model of 16 columns | Extended to 17 columns to accommodate the SHA-256 hashes in new separate column 13 (original columns 13+14+15+16 shifted to 14+15+16+17)
&nbsp; | New check for falsely detected hardlinks: SHA-256 hash differs
Option **--hLinks** | Renamed to **--detectHLinksS** (more descriptive option name)
Option **--touch** | Renamed to **--extraTouch** (more descriptive option name)
&nbsp; | New Sanity Check for column 6 not alphanumeric
&nbsp; | More stringent directories hierarchy check
&nbsp; | Minor code improvements and optimizations
Code size 76 kB | Code size 96 kB
Docu size 78 kB | Docu size 88 kB

## License
MIT License
