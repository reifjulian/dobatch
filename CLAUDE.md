# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**dobatch** is a Stata package that runs do-files as parallel background batch processes on Unix-based systems (macOS/Linux) and Windows. It requires Stata MP and monitors system resources (CPU availability, active Stata processes) to prevent server overload. The companion command `dobatch_wait` pauses execution until background jobs complete. On Unix, shell commands use `nohup`/`ps`/`uptime`; on Windows, PowerShell handles process launching, CPU monitoring, and process detection.

## Repository Structure

- `src/` - Stata source files: `dobatch.ado`, `dobatch_wait.ado`, and their `.sthlp` help files
- `test/` - Test suite (`dobatch_tests.do`) and helper do-files (`dofile1.do`, `dofile2.do`)
- `dobatch.pkg` and `stata.toc` - Stata package distribution metadata

## Running Tests

From the `test/` directory in Stata:
```stata
do dobatch_tests.do
```

The test script adds `../src` to `adopath` automatically. Tests are platform-aware: both Windows and Unix run the full parallel execution suite using platform-appropriate system commands.

## Key Architecture

**dobatch.ado** launches do-files as background batch processes. On Unix, it uses `nohup stata-mp -b do` shell commands. On Windows, it uses PowerShell `Start-Process` with `-WindowStyle Hidden` and the `/e` batch mode flag. Before launching, it polls system resources (CPU load, active Stata processes) and delays execution if thresholds are exceeded. Process IDs are accumulated in the global macro `DOBATCH_STATA_PID`.

**dobatch_wait.ado** polls for process completion. On Unix, it uses `ps` with the stored PIDs. On Windows, it uses PowerShell `Get-Process`. It supports waiting for all tracked PIDs (default) or a specific PID passed via the `pid()` option.

**Platform detection** uses `c(os)=="Windows"` to branch between Windows (PowerShell) and Unix (shell) code paths.

**Configuration globals** (set by user before calling dobatch):
- `DOBATCH_DISABLE` - run in foreground like `do`
- `DOBATCH_MIN_CPUS_AVAILABLE` - minimum free CPUs required
- `DOBATCH_MAX_STATA_JOBS` - maximum concurrent Stata MP processes
- `DOBATCH_WAIT_TIME_MINS` - polling interval; set to 0 to skip resource monitoring

## Running Stata on Windows

Stata is typically located at `C:\Program Files\Stata19\StataMP-64.exe`. To run a `.do` file in batch mode, use PowerShell:

```bash
powershell.exe -Command "Start-Process -FilePath 'C:\Program Files\Stata19\StataMP-64.exe' -ArgumentList '/e do script.do' -WorkingDirectory '<directory>' -Wait -NoNewWindow"
```

- The `/e` flag tells Stata to execute the script and exit (batch mode).
- `-Wait` ensures the command blocks until Stata finishes.
- `-WorkingDirectory` sets the working directory for the Stata session (e.g., the `test/` subdirectory of the project).
- Output is written to a `.log` file in the working directory with the same base name as the `.do` file (e.g., `timing.do` produces `timing.log`).

## Stata Conventions

- Minimum Stata version: 13.0
- Ado-files use `syntax` for argument parsing and `return scalar` for stored results
- Help files use SMCL markup format
- Package is installed via `net install` from the GitHub raw URL
