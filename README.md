# PEDRO SYSTEM

**Personal Environment & Device Resource Operations**

PEDRO SYSTEM is a local PowerShell command center for Windows. It provides system monitoring, process inspection, application launchers, networking tools, storage checks, read-only security checks, safe maintenance helpers, gaming shortcuts, logs and reports through a custom `pedro>` shell.

The project is designed primarily for **Windows PowerShell 5.1** and also aims to work on **PowerShell 7+** when the Windows cmdlets used by a feature are available.

## Architecture

The entry point (`PEDRO.ps1`) dot-sources small modules under `core/`. The command interpreter uses a central dispatcher instead of a large chain of `if` statements. System data retrieval is kept separate from presentation where practical so the same functions can later feed a GUI.

```text
PEDRO-SYSTEM/
|-- PEDRO.ps1
|-- PEDRO.cmd
|-- install.ps1
|-- uninstall.ps1
|-- README.md
|-- core/
|   |-- common.ps1
|   |-- commands.ps1
|   |-- system.ps1
|   |-- monitor.ps1
|   |-- processes.ps1
|   |-- network.ps1
|   |-- storage.ps1
|   |-- security.ps1
|   |-- maintenance.ps1
|   |-- applications.ps1
|   `-- gaming.ps1
|-- config/
|   |-- apps.json
|   |-- aliases.json
|   `-- settings.json
|-- data/
|   `-- history/
|-- logs/
|   `-- system.log
`-- reports/
```

## Main commands

```text
help                 List commands
help open            Help for a command
status               General system status
monitor              Live CPU/RAM/GPU/disk/network monitor
processes            Top processes by CPU and RAM
process chrome       Inspect a process
apps                  List configured apps
apps add name path    Register an executable
alias                  List aliases
alias add code vscode  Create/update an alias
alias remove code      Remove an alias
open chrome           Open configured app
close chrome          Close configured app safely
network               Adapter/IP/gateway/DNS information
ping google.com       Connection/latency test
dns example.com       DNS query
disk                  Fixed drive usage
security              Defender/firewall/antivirus status
clean                 Safe maintenance menu
repair                Alias for maintenance menu
gaming                Gaming launcher/monitor
gaming close chrome   Close a non-critical app
report                 Generate TXT report
diagnostics            Quick local health check
settings               Show settings
settings set historySize 60
clear
exit
```

Aliases in `config/aliases.json` can be typed directly, for example `chrome`, `code`, `discord` and `steam`.

## First run without installing

Open **PowerShell** in the extracted project folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\PEDRO.ps1
```

This policy change applies only to the current PowerShell process.

## Install the global `pedro` command

From the extracted project folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

Default installation directory:

```text
C:\PedroSystem
```

The installer copies the project and adds `C:\PedroSystem` to the **current user's PATH**, so administrator privileges are normally not needed for installation.

After installation, **close and reopen CMD or PowerShell**. Then run:

```text
pedro
```

You can also use **Win + R**, type `pedro`, and press Enter after the PATH refreshes.

To install somewhere else:

```powershell
.\install.ps1 -InstallPath 'D:\Tools\PedroSystem'
```

## Uninstall

Run from the installed folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\uninstall.ps1
```

The uninstaller removes the installation path from the user PATH and asks before deleting the folder.

## Configure applications

Default application locations are examples and may not match every Windows installation. Check them with:

```text
apps
```

Register or replace an app:

```text
apps add chrome "C:\Program Files\Google\Chrome\Application\chrome.exe"
apps add vscode "C:\Users\YOUR_USER\AppData\Local\Programs\Microsoft VS Code\Code.exe"
```

Application entries support environment variables and simple wildcards, which is useful for versioned folders such as Discord.

## Safety model

PEDRO SYSTEM does not intentionally disable antivirus, disable firewall, modify persistence settings, upload system data, or automatically delete arbitrary files. Critical Windows process names are blocked from the `close` command. Maintenance operations that delete temporary files or invoke SFC/DISM require confirmation; Windows elevation may appear where needed.

Logs never intentionally include passwords or secrets. Log rotation is controlled by `logMaxMB` in `config/settings.json`.

## Metrics and limitations

- **CPU:** obtained from Windows/CIM data. Instant values vary by sampling method.
- **RAM:** based on `Win32_OperatingSystem` physical memory values.
- **GPU model:** read from `Win32_VideoController`.
- **GPU usage:** attempts to use the native `GPU Engine` performance counter. Older GPUs, older WDDM drivers, remote sessions, or some Windows configurations may not expose it. In those cases PEDRO SYSTEM shows `N/A` instead of failing.
- **GPU temperature / CPU temperature:** not implemented because Windows does not provide reliable universal native sensor readings for consumer hardware. Adding hardware-vendor or third-party sensor libraries would violate the project's no-unnecessary-dependencies goal.
- **Network throughput in monitor:** local interface bytes/sec converted to Mbps. It is current traffic, **not an internet speed test**.
- **Internet state:** checks reachability of `1.1.1.1`; some networks block ICMP and can therefore produce a false offline result.
- **Security:** reads available Defender, Firewall and Security Center information. It is a basic status view, not a replacement for an antivirus/security audit.
- **Updates:** the latest installed hotfix is displayed; PEDRO SYSTEM does not claim this proves every Windows update is installed.

## Reports and history

`report` writes timestamped TXT files under `reports/`.

The real-time monitor appends local JSON Lines samples under `data/history/`. The number of lines retained per daily history file is bounded by `metricHistoryMaxLines`, preventing unlimited growth.

## Test checklist

```text
[ ] PEDRO starts
[ ] help works
[ ] help open works
[ ] status works
[ ] monitor works and Q exits
[ ] CPU displays a value or safe N/A
[ ] RAM displays a value
[ ] GPU displays a value or safe N/A
[ ] disk works
[ ] network works
[ ] ping works
[ ] dns works
[ ] apps works
[ ] apps add works
[ ] open works for a configured app
[ ] close works for a configured non-critical app
[ ] protected Windows processes are blocked
[ ] processes works
[ ] process <name> works
[ ] security works without changing protections
[ ] clean asks before destructive/administrative operations
[ ] gaming opens
[ ] diagnostics works
[ ] report creates a file
[ ] logs/system.log receives entries
[ ] monitor writes bounded metric history
[ ] install.ps1 adds the user PATH entry
[ ] a new terminal can run: pedro
[ ] uninstall.ps1 removes the PATH entry
```

## Suggested future evolution

The next major version should keep the PowerShell data collectors but expose them through a stable internal object model. A GUI can then be built on top (for example WPF for a Windows-native interface) without rewriting monitoring logic. Useful later additions include startup-app inspection, Windows services browsing, event-log summaries, battery health on laptops, Wi-Fi details and an optional HTML report exporter.
