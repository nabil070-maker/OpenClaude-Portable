# OpenClaude Portable

Run [OpenClaude](https://github.com/Twigpine/openclaude) from a single USB drive or folder on **Windows** and **Linux**, with no install and no changes to the host PC.

![Windows](https://img.shields.io/badge/Windows-x64-0078D4?logo=windows&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-FCC624?logo=linux&logoColor=black)
![Node.js](https://img.shields.io/badge/Node.js-24%20LTS-339933?logo=node.js&logoColor=white)

> **Unofficial.** This project is not affiliated with Anthropic or the OpenClaude authors. It only downloads and launches OpenClaude with a portable environment.

## Features

- **Self-contained:** bundles its own Node.js, ripgrep and (on Windows) PortableGit.
- **No host changes:** no global install, no PATH or registry edits, no admin rights.
- **Redirected storage:** config, caches and temp files stay on the drive.
- **Cross-OS:** one folder works on Windows and Linux. Each OS gets its own runtime, and your settings are shared.
- **Verified downloads:** SHA-256 checks on every downloaded tool.
- **Privacy defaults:** auto-update, telemetry and error reporting are switched off.
- **Easy updates:** one command updates OpenClaude and the bundled tools.

## Quick start

1. Download or clone this repository onto your drive.
2. Run the launcher. The first run downloads everything and needs internet.

| OS | Command |
|----|---------|
| Windows | Double-click `launch.bat` |
| Linux | `./launch.sh` (or `bash launch.sh` if the drive blocks execution) |

3. Inside OpenClaude, run `/provider` to choose and save your model backend.

**Requirements**

- Windows 64-bit (Intel/AMD) or Linux (x64 / arm64)
- `curl` or `wget` on Linux
- Roughly 500 MB of free space on Windows and 200 MB on Linux (approximate)

## Updating

```
launch.bat --portable-update        # Windows
./launch.sh --portable-update       # Linux
```

This installs the latest OpenClaude. To change the bundled Node.js, ripgrep or PortableGit versions, edit `versions.txt` first, then run the update. Clear a tool's SHA-256 line when you change that tool's version, or paste the new hash.

## Folder layout

```
OpenClaude-Portable/
  launch.bat, launch.sh      launchers
  versions.txt               tool versions, package name, checksums
  scripts/                   setup.ps1 (Windows), setup.sh (Linux)
  runtime/win, runtime/linux Node.js, ripgrep, PortableGit (Windows)
  app/win, app/linux         OpenClaude installs, one per OS
  profile/                   fake HOME/AppData/config, shared by both OSes
  cache/, temp/              npm cache and scratch space (temp wiped on exit)
  workspace/                 default working folder
```

Everything except the launchers, scripts, `versions.txt` and this README is created on first run.

## How it works

The launcher sets these for its own process only:

| Setting | Points to |
|---------|-----------|
| `HOME`, `USERPROFILE` | `profile/home` |
| `APPDATA`, `LOCALAPPDATA` (Windows) | `profile/appdata`, `profile/localappdata` |
| `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` | `profile/`, `cache/` |
| `TEMP`, `TMP`, `TMPDIR` | `temp/` |
| `OPENCLAUDE_CONFIG_DIR`, `CLAUDE_CONFIG_DIR` | `profile/openclaude` |
| npm cache and user config | `cache/npm`, `profile/home/.npmrc` |
| `CLAUDE_CODE_GIT_BASH_PATH` (Windows) | bundled `bash.exe` |
| `DISABLE_AUTOUPDATER`, `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` |

OpenClaude is installed with `npm install --no-bin-links` and started by running its entry file directly with the bundled Node. This avoids symlinks, which exFAT and FAT32 drives do not support. The entry path is stored relative to the app folder, so changing drive letters or mount points is fine.

## Security notes

- **API keys are stored in plain text** inside `profile/`. Anyone who finds the drive can read them. Use a drive you trust, or encrypt it (BitLocker To Go on Windows, LUKS on Linux).
- Downloads come from nodejs.org and GitHub releases and are verified by SHA-256. Node.js is checked against nodejs.org's `SHASUMS256.txt`. The other tools use hashes pinned in `versions.txt`.
- The scripts refuse to run setup outside the launcher, so nothing is written to the real home folder by accident.

## Limitations

"No trace" means no files or settings are left behind. It does not hide that something ran.

- Windows still records program use (Prefetch, Recent items, event logs, USB connection history).
- Linux shells save the command in their history. Start with a leading space (if `HISTCONTROL=ignorespace`) or run `HISTFILE=/dev/null bash launch.sh`.
- Official Node.js Linux builds need glibc, so Alpine and other musl distros are not supported.
- Windows on ARM is not supported by the setup script.
- Windows needs PortableGit because OpenClaude requires `bash.exe` there.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Permission denied` on Linux | Run `bash launch.sh`, or remount the drive with exec permission. |
| Node will not start from the drive | The drive may be mounted `noexec`. Remount it or copy the folder to a Linux filesystem. |
| `requires git-bash` on Windows | Delete `runtime\win\git` and `runtime\win\git.ver`, then launch again to reinstall PortableGit. |
| `Checksum mismatch` | The download was corrupted or the pinned hash is outdated. Retry, or update `versions.txt`. |
| Download fails behind a proxy | Set `HTTPS_PROXY` in your shell before launching. |
| Antivirus flags or slows setup | PortableGit unpacks many files. Allow the drive folder temporarily or retry. |
| Shell script errors on Linux | Convert line endings: `sed -i 's/\r$//' launch.sh scripts/setup.sh` |

## Status

Linux support was tested end to end (first run, folder moves, updates, checksum rejection, no writes to the host home or temp). Windows support is newer and less tested. Please open an issue if something fails.

## Contributing

Issues and pull requests are welcome. Please include your OS, the drive's filesystem, and the full error output.

## License

MIT, see [LICENSE](LICENSE). OpenClaude, Node.js, ripgrep and Git for Windows are downloaded at setup time and keep their own licenses.