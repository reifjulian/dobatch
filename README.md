# DOBATCH: Run Stata dofiles in parallel

- Current dobatch version: `1.0 5feb2025`
- Jump to:  [`overview`](#overview) [`installation`](#installation) [`author`](#author)

-----------

## Overview

`dobatch` runs *filename* in batch mode in the background, allowing multiple do-files to execute in parallel. It requires Stata MP and a Unix-based system. Before execution, `dobatch` checks server usage to ensure sufficient CPU availability and to prevent an excessive number of active Stata processes.

This command is currently being beta tested.

## Installation

```stata
* Determine which version of -dobatch- you have installed
which dobatch

* Install the most recent version of -dobatch-
net install dobatch, from("https://raw.githubusercontent.com/reifjulian/dobatch/master") replace
```

## Author

[Julian Reif](http://www.julianreif.com)
<br>University of Illinois
<br>jreif@illinois.edu
