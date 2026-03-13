*! dobatch 1.2 10mar2026 by Julian Reif

program define dobatch, rclass

* Optional params for dobatch are specified in the following globals:
*   DOBATCH_DISABLE
*   DOBATCH_MIN_CPUS_AVAILABLE
*   DOBATCH_MAX_STATA_JOBS
*   DOBATCH_WAIT_TIME_MINS

	version 13.0

	* If dobatch is disabled, just run the dofile as normal
	if `"$DOBATCH_DISABLE"'=="1" {
		do `0'
		exit
	}

	* Detect platform
	local is_windows = (c(os)=="Windows")
	* First argument must be dofilename, followed by optional arguments to the dofile
	syntax anything [, nostop EXE(string)]
	gettoken dofile args : anything
	cap confirm file "`dofile'"
	if _rc cap confirm file "`dofile'.do"
	if _rc confirm file "`dofile'"

	* Set default values for how many CPUs need to be available and for max number of active Stata jobs
	*  (1) MIN_CPUS_AVAILABLE = (# Stata-MP license cores) - 1
	*  (2) MAX_STATA_JOBS = (# cores) / (# Stata-MP license cores). If <2, set to 2.
	*  Note: c(processors_mach) evaluates to missing when running non-MP Stata.
	local num_cpus_machine = c(processors_mach)
	local num_cpus_statamp = c(processors_lic)
	local default_min_cpus_available = max(`num_cpus_statamp' - 1,1)
	local default_max_stata_jobs = max(floor(`num_cpus_machine' / `num_cpus_statamp'), 2)  // for non-MP, c(processors_mach) is missing; max(.,2)=2 since Stata's max() ignores missings

	local MIN_CPUS_AVAILABLE = `default_min_cpus_available'
	local MAX_STATA_JOBS = `default_max_stata_jobs'

	* Default wait time is 5 minutes
	local WAIT_TIME_MINS = 5

	* The default values above can be overriden by user-defined global macros
	foreach param in MIN_CPUS_AVAILABLE MAX_STATA_JOBS WAIT_TIME_MINS {
		if !mi(`"${DOBATCH_`param'}"') {
			cap confirm number ${DOBATCH_`param'}
			if _rc {
				noi di as error _n "Error parsing the global variable DOBATCH_`param'"
				confirm number ${DOBATCH_`param'}
			}
			local `param' = ${DOBATCH_`param'}

			if "`param'"=="WAIT_TIME_MINS" noi di as text "Wait time set to " as result "`WAIT_TIME_MINS'" as text " minutes"
		}
	}
	if `MAX_STATA_JOBS' < 1 {
		noi di as error "DOBATCH_MAX_STATA_JOBS must be at least 1"
		exit 198
	}
	noi di as text _n "Minimum required available CPUs: " as result `MIN_CPUS_AVAILABLE'
	noi di as text "Maximum number of background Stata jobs allowed: " as result `MAX_STATA_JOBS'

	tempname fh
	tempfile tmp


	************************************************
	* Find the Stata executable
	************************************************
	_dobatch_get_exe, exe("`exe'") iswindows(`is_windows')
	local stata_exe = r(stata_exe)


	************************************************
	* Check server usage
	************************************************

	* If check_cpus=1, wait until there are (1) at least MIN_CPUS_AVAILABLE CPUs available; and (2) less than MAX_STATA_JOBS active Stata processes
	*   - If wait time is non-positive, skip this code (ie, set check_cpus = 0)
	local check_cpus 1
	if `WAIT_TIME_MINS'<=0 local check_cpus = 0
	while (`check_cpus'==1) {

		if `is_windows' {
			* Get CPU load percentage (0-100) via PowerShell
			cap rm `tmp'
			qui shell powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average" > `tmp'
			file open `fh' using `tmp', read
			file read `fh' line
			file close `fh'
			local load_pct = trim("`line'")
			cap confirm number `load_pct'
			if _rc {
				di as error "Error parsing CPU load percentage:"
				di as error `"powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average""'
				confirm number `load_pct'
			}
			local free_cpus = `num_cpus_machine' * (100 - `load_pct') / 100
		}
		else {
			cap rm `tmp'
			qui shell sh -c 'LANG=C uptime | sed -E "s/.*load average[s]?: //" | tr -s " ," "," | cut -d"," -f1' > `tmp'
			file open `fh' using `tmp', read
			file read `fh' line
			file close `fh'
			local one_min_load_avg = trim("`line'")
			cap confirm number `one_min_load_avg'
			if _rc {
				di as error "Error parsing the load average:"
				di as error `"shell sh -c 'LANG=C uptime | sed -E "s/.*load average[s]?: //" | tr -s " ," "," | cut -d"," -f1'"'
				confirm number `one_min_load_avg'
			}
			local free_cpus = `num_cpus_machine' - `one_min_load_avg'
		}
		noi di _n "Available CPUs at $S_TIME: `free_cpus'"

		* Count number of background Stata processes
		if `is_windows' {
			cap rm `tmp'
			qui shell powershell -NoProfile -Command "@(Get-Process -Name 'Stata*' -ErrorAction SilentlyContinue).Count" > `tmp'
			file open `fh' using `tmp', read
			file read `fh' line
			file close `fh'
			local num_stata_jobs = trim("`line'")
			if mi("`num_stata_jobs'") local num_stata_jobs = 0
			cap confirm integer number `num_stata_jobs'
			if _rc {
				di as error "Error counting the number of background Stata processes:"
				di as error `"powershell -NoProfile -Command "@(Get-Process -Name 'Stata*' -ErrorAction SilentlyContinue).Count""'
				confirm integer number `num_stata_jobs'
			}
			* Subtract one to exclude the parent process (this script)
			local num_stata_jobs = `num_stata_jobs'-1
		}
		else {
			* Count background Stata processes via ps/grep (case-insensitive to catch both GUI and CLI processes)
			local stata_grep "[Ss]tata"
			cap rm `tmp'
			qui shell ps aux | grep '`stata_grep'' | wc -l > `tmp'
			file open `fh' using `tmp', read
			file read `fh' line
			file close `fh'
			local num_stata_jobs = trim("`line'")
			cap confirm integer number `num_stata_jobs'
			if _rc {
				di as error "Error counting the number of background Stata processes:"
				di as error `"shell ps aux | grep '`stata_grep'' | wc -l"'
				confirm integer number `num_stata_jobs'
			}
			local num_stata_jobs = `num_stata_jobs'-1
		}
		noi di "Background Stata jobs at $S_TIME: `num_stata_jobs'"

		* If server is busy, wait a few minutes and try again
		if `free_cpus' < `MIN_CPUS_AVAILABLE' | `num_stata_jobs' >= `MAX_STATA_JOBS' {
			noi di "Waiting for at least `MIN_CPUS_AVAILABLE' available CPUs and fewer than `MAX_STATA_JOBS' background Stata jobs..."
			sleep `=1000*60*`WAIT_TIME_MINS''
		}
		else local check_cpus = 0
	}

	************************************************
	* Run Stata in batch mode
	************************************************
	tempname stata_pid_fh
	tempfile stata_pid_file

	if !mi("`stop'") local stop ", `stop' "

	if `is_windows' {
		* Use Start-Process with -WindowStyle Hidden for background execution
		* /e is the Windows batch mode flag (equivalent to -b on Unix)
		local ps_cmd `"(Start-Process -FilePath '`stata_exe'' -ArgumentList '/e do \"`dofile'\" `args' `stop'' -WorkingDirectory '`c(pwd)'' -PassThru -WindowStyle Hidden).Id"'
		noi di _n `"powershell -NoProfile -Command "`ps_cmd'""'
		qui shell powershell -NoProfile -Command "`ps_cmd'" > `stata_pid_file'
	}
	else {
		local prefix `"nohup "`stata_exe'" -b do"'
		local suffix "</dev/null >/dev/null 2>&1 & echo $! > `stata_pid_file'"

		noi di _n `"sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''"'
		shell sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''
	}

	* Store the process ID number
	file open `stata_pid_fh' using `"`stata_pid_file'"', read
	file read `stata_pid_fh' stata_pid
	file close `stata_pid_fh'
	local stata_pid = trim(`"`stata_pid'"')
	cap confirm number `stata_pid'
	if _rc local stata_pid = .
	if !mi(`stata_pid') global DOBATCH_STATA_PID "$DOBATCH_STATA_PID `stata_pid'"
	global DOBATCH_STATA_PID = trim("$DOBATCH_STATA_PID")

	* Return parameter values
	return scalar PID = `stata_pid'
	return scalar MIN_CPUS_AVAILABLE = `MIN_CPUS_AVAILABLE'
	return scalar MAX_STATA_JOBS = `MAX_STATA_JOBS'
	return scalar WAIT_TIME_MINS = `WAIT_TIME_MINS'
end


program define _dobatch_get_exe, rclass

	version 13.0

	syntax [, EXE(string) ISwindows(integer 0)]

	tempfile tmp

	* Determine edition-specific executable names
	* Use c(MP)/c(SE) as primary (reliable since Stata 9+)
	* Use c(flavor) only to distinguish IC vs BE (available since Stata 14)
	if c(MP)==1 {
		local winexebase "StataMP"
		local unixexename "stata-mp"
		local macappname "StataMP"
	}
	else if c(SE)==1 {
		local winexebase "StataSE"
		local unixexename "stata-se"
		local macappname "StataSE"
	}
	else {
		* IC or BE: use c(flavor) to distinguish if available (Stata 14+), default to IC naming
		if c(flavor)=="BE" {
			local winexebase "StataBE"
			local unixexename "stata"
			local macappname "StataBE"
		}
		else {
			local winexebase "Stata"
			local unixexename "stata"
			local macappname "Stata"
		}
	}

	* If exe() is provided, try it first; otherwise auto-detect
	if !mi("`exe'") {
		cap confirm file "`exe'"
		if !_rc {
			return local stata_exe "`exe'"
			exit
		}
		if `iswindows' {
			local statadir = c(sysdir_stata)
			cap confirm file "`statadir'`exe'"
			if !_rc {
				return local stata_exe "`statadir'`exe'"
				exit
			}
			di as error "Executable not found: tried `exe' and `statadir'`exe'"
			di as error "Specify a full absolute path with exe() if needed."
			exit 601
		}
		else {
			* Try PATH
			cap rm `tmp'
			qui shell sh -c 'command -v "`exe'" >/dev/null && touch `tmp''
			cap confirm file `tmp'
			if !_rc {
				return local stata_exe "`exe'"
				exit
			}
			di as error "Executable not found: tried `exe' as a file path and on PATH"
			di as error "Specify a full absolute path with exe() if needed."
			exit 601
		}
	}

	* Auto-detect based on platform and edition
	if `iswindows' {
		local statadir = c(sysdir_stata)
		cap confirm file "`statadir'`winexebase'-64.exe"
		if !_rc {
			return local stata_exe "`statadir'`winexebase'-64.exe"
			exit
		}
		cap confirm file "`statadir'`winexebase'.exe"
		if !_rc {
			return local stata_exe "`statadir'`winexebase'.exe"
			exit
		}
		di as error "`winexebase' executable not found in `statadir'"
		di as error "Ensure `winexebase'-64.exe or `winexebase'.exe exists in the Stata installation directory."
		di as error "Alternatively, specify the executable using the exe() option."
		exit 601
	}
	else {
		* Unix/macOS: try sysdir, then macOS .app bundle, then PATH
		local statadir = c(sysdir_stata)
		cap confirm file "`statadir'`unixexename'"
		if !_rc {
			return local stata_exe "`statadir'`unixexename'"
			exit
		}
		* Try macOS .app bundle: <sysdir>/<AppName>.app/Contents/MacOS/<unixexename>
		local mac_path "`statadir'`macappname'.app/Contents/MacOS/`unixexename'"
		cap confirm file "`mac_path'"
		if !_rc {
			return local stata_exe "`mac_path'"
			exit
		}
		* Fallback: try PATH
		cap rm `tmp'
		qui shell sh -c 'command -v `unixexename' >/dev/null && touch `tmp''
		cap confirm file `tmp'
		if !_rc {
			return local stata_exe "`unixexename'"
			exit
		}
		di as error "`unixexename' not found in `statadir' or on PATH."
		di as error "Alternatively, specify the executable using the exe() option."
		exit 601
	}
end

** EOF
