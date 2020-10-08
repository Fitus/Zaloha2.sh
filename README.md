# Zaloha2.sh

Zaloha2.sh is the next step in development of [Zaloha.sh](https://github.com/Fitus/Zaloha.sh), the small and simple directory synchronizer (a BASH script).

## Why a new repository and program name?

 * Some design changes break backward compatibility (see full list of changes below).
 * To keep the original [Zaloha.sh](https://github.com/Fitus/Zaloha.sh) intact for the conservative user.

## Documentation

Full documentation is available both [online](DOCUMENTATION.md) as well as inside of Zaloha2.sh.

For all other documentation and explanatory items (Article, Flowchart, Screenshot, Simple Demo, Performance Data) refer to the original
[Zaloha.sh](https://github.com/Fitus/Zaloha.sh) repository.

## New feature 1: The Remote Backup Mode

In the Remote Backup Mode, the source directory is available locally, and the backup directory is on a remote backup host that can be reached via SSH/SCP.
This mode is activated by the option **--backupUserHost**.

### The Remote Backup Mode explained in eight sentences

 * The FIND scan of the source directory occurs locally (no change against Zaloha.sh).
 * The script for FIND scan of the backup directory (file 220) is prepared locally.
 * The script is then copied to the remote backup host via SCP and executed via SSH.
 * The obtained CSV metadata (file 320) is copied back from the remote backup host via SCP.
 * The CSV metadata is compared by a sequence of sorts and AWK processing steps (occurs locally).
 * The results (= prepared synchronization actions) are presented to the user for confirmation.
 * If the user confirms, the synchronization actions are executed (via SSH and SCP).
 * A non-interactive regime is available as well.

### Usage Example of the Remote Backup Mode

```bash
# Establish the SSH master connection
ssh -nNf -o ControlMaster=yes -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@backuphost'

# Run Zaloha2.sh
./Zaloha2.sh --sourceDir="test_source_local"     \
             --backupDir="test_backup_remote"    \
             --backupUserHost='user@backuphost'  \
             --sshOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'     \
             --scpOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p -T'

# Terminate the SSH master connection
ssh -O exit -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@backuphost'
```

## New feature 2: The Remote Source Mode

In the Remote Source Mode, the source directory is on a remote source host that can be reached via SSH/SCP, and the backup directory is available locally.
This mode is activated by the option **--sourceUserHost**.

### The Remote Source Mode explained in eight sentences

 * The script for FIND scan of the source directory (file 210) is prepared locally.
 * The script is then copied to the remote source host via SCP and executed via SSH.
 * The obtained CSV metadata (file 310) is copied back from the source host via SCP.
 * The FIND scan of the backup directory occurs locally (no change against Zaloha.sh).
 * The CSV metadata is compared by a sequence of sorts and AWK processing steps (occurs locally).
 * The results (= prepared synchronization actions) are presented to the user for confirmation.
 * If the user confirms, the synchronization actions are executed.
 * A non-interactive regime is available as well.

### Usage Example of the Remote Source Mode

```bash
# Establish the SSH master connection
ssh -nNf -o ControlMaster=yes -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@sourcehost'

# Run Zaloha2.sh
./Zaloha2.sh --sourceDir="test_source_remote"     \
             --backupDir="test_backup_local"    \
             --sourceUserHost='user@sourcehost'  \
             --sshOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p'     \
             --scpOptions='-o ControlMaster=no -o ControlPath=~/.ssh/cm-%r@%h:%p -T'

# Terminate the SSH master connection
ssh -O exit -o ControlPath='~/.ssh/cm-%r@%h:%p' 'user@sourcehost'
```

## New feature 3: Compare the contents of files via SHA-256 hashes

The option **--byteByByte** cannot be used in the Remote Source and Remote Backup Modes, because the CMP command needs local access to both compared files.

For the remote modes, a new option **--sha256** has been introduced. This option causes both FIND scans to additionally
invoke SHA256SUM on each encountered file. Note that the SHA-256 hashes of the files are calculated on the hosts where the files are located.
Also no contents of files are transferred over the network, just the SHA-256 hashes.
The SHA-256 hashes are then compared to detect files that appear identical but their contents differ.

## Obtain Zaloha2.sh

The simplest way: Under the green button "<b>Code</b>" above, choose "<b>Download ZIP</b>".
From the downloaded ZIP archive, extract Zaloha2.sh and make it executable (<b>chmod u+x Zaloha2.sh</b>).

## Add-on script Zaloha2_Snapshot.sh

The script for hardlink-based snapshots has been adapted to Zaloha2.sh: [Zaloha2_Snapshot](https://github.com/Fitus/Zaloha2_Snapshot.sh).
This allows to create **Time&nbsp;Machine**-like backup solutions.

## Full list of changes and new features of Zaloha2.sh

Zaloha.sh&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Zaloha2.sh
--------- | ----------
&nbsp; | New option **--sourceUserHost** to activate the Remote Source Mode via SSH/SCP
&nbsp; | New option **--backupUserHost** to activate the Remote Backup Mode via SSH/SCP
&nbsp; | New option **--sshOptions** to pass additional command-line options to SSH in the remote modes
&nbsp; | New option **--scpOptions** to pass additional command-line options to SCP in the remote modes
&nbsp; | New option **--findParallel** to run the local and remote FIND scans in parallel in the remote modes
Option **--metaDir** | In Remote Backup Mode: allows to place the Zaloha metadata directory on the remote backup host to a different location than the default.
&nbsp; | New option **--metaDirTemp**: In the remote modes, Zaloha needs a temporary Metadata directory too. This option allows to place it to a different location than the default.
Shellscript **610** | In Remote Backup Mode: executed on the remote side
Shellscript **620** | Split to **621** (pre-copy), **622** (copy), **623** (post-copy). In Remote Backup Mode: **621** and **623** are executed on the remote side. In both remote modes, **622** contains SCP commands instead of CP commands.
Shellscript **630** | Split to **631** (pre-copy), **632** (copy), **633** (post-copy). In Remote Source Mode: **631** and **633** are executed on the remote side. In both remote modes, **632** contains SCP commands instead of CP commands.
Shellscript **640** | In Remote Backup Mode: executed on the remote side
Shellscript **650** | Split to **651** (pre-copy), **652** (copy), **653** (post-copy). In Remote Backup Mode: **651** and **653** are executed on the remote side. In both remote modes, **652** contains SCP commands instead of CP commands.
Restore script **810** | In the remote modes: contains SCP commands instead of CP commands
&nbsp; | New option **--sha256** for comparing the contents of files via SHA-256 hashes
CSV data model of **16&nbsp;columns** | Extended to **17&nbsp;columns** to accommodate the SHA-256 hashes in new separate column 13 (original columns 13+14+15+16 shifted to 14+15+16+17)
&nbsp; | New check for falsely detected hardlinks: SHA-256 hash differs
Option **--hLinks** | Renamed to **--detectHLinksS** (more descriptive option name)
Option **--touch** | Renamed to **--extraTouch** (more descriptive option name)
Option **--noExec1Hdr** | Renamed to **--no610Hdr**
Option **--noExec2Hdr** | Replaced by finer-grained options **--no621Hdr**, **--no622Hdr** and **--no623Hdr**
Option **--noExec3Hdr** | Replaced by finer-grained options **--no631Hdr**, **--no632Hdr** and **--no633Hdr**
Option **--noExec4Hdr** | Renamed to **--no640Hdr**
Option **--noExec5Hdr** | Replaced by finer-grained options **--no651Hdr**, **--no652Hdr** and **--no653Hdr**
&nbsp; | New Sanity Check for column 6 not alphanumeric
&nbsp; | More stringent directories hierarchy check
&nbsp; | Minor code improvements and optimizations
Code size 76 kB | Code size 104 kB
Docu size 78 kB | Docu size 90 kB

## License
MIT License
