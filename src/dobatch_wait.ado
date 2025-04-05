*! dobatch_wait 1.0 28mar2025 by Julian Reif

* Helper program that waits for jobs to end. Two modes:
*  (1) default: wait until all Stata MP jobs end (excluding this one)
*  (2) if process ID numbers (PIDs) are provided as input, wait until each one has ended
program define dobatch_wait, rclass

	* If dobatch is disabled, do nothing
	if `"$DOBATCH_DISABLE"'=="1" {
		exit
	}
	
	* dobatch_wait requires Unix-based system
	cap assert c(os)!="Windows"
	if _rc {
		noi di as error "dobatch_wait requires Unix or macOS"
		exit 198
	}	

	* PIDs must be positive integers. If not specified, pull PIDs from DOBATCH_STATA_PID
	syntax [, pid(numlist >0 integer)]
	if mi("`pid'") & !mi("$DOBATCH_STATA_PID") {
		local 0 ", pid($DOBATCH_STATA_PID)"
		cap syntax [, pid(numlist >0 integer)]
		if _rc {
			di as error "Error parsing the global variable DOBATCH_STATA_PID"
			di as error "DOBATCH_STATA_PID must contain only positive integers"
			exit 198
		}
		local pid_from_dobatch_stata_pid = 1
	}	
	
	* Default wait time is 5 minutes
	local WAIT_TIME_MINS = 5
	
	* The default values above can be overriden by user-defined global macros
	foreach param in WAIT_TIME_MINS {
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

	tempfile tmp
	tempname fh
	
	***
	* Case 1: default behavior is waiting for all Stata jobs (except this one) to end
	*   - Code duplicates dobatch, but checks only that `num_stata_jobs' > 0 and has different message
	***
	if mi("`pid'") {

		local check_cpus 1
		if `WAIT_TIME_MINS'<=0 local check_cpus = 0
		while (`check_cpus'==1) {
			
			* Count number of background stata-mp processes. Subtract one to exclude the parent process (this script).
			cap rm `tmp'
			qui shell ps aux | grep '[s]tata-mp' | wc -l > `tmp'
			file open `fh' using `tmp', read
			file read `fh' line
			file close `fh'
			local num_stata_jobs = trim("`line'")
			cap confirm integer number `num_stata_jobs'
			if _rc {
				di as error "Error counting the number of background Stata processes"
				confirm integer number `num_stata_jobs'
			}
			else local num_stata_jobs = `num_stata_jobs'-1
			noi di "Background Stata MP jobs at $S_TIME: `num_stata_jobs'"
					
			* If server is busy, wait a few minutes and try again
			if `num_stata_jobs' > 0 {
				noi di "Waiting for background Stata MP jobs to end..."
				sleep `=1000*60*`WAIT_TIME_MINS''
			}
			else local check_cpus = 0
		}
	}
	
	***
	* Case 2: user (or DOBATCH_STATA_PID) provides PIDs
	***
	else {
		noi di "Wait for the following jobs to end: `pid'" _n
		
		local check_cpus 1
		if `WAIT_TIME_MINS'<=0 local check_cpus = 0
		while (`check_cpus'==1) {
			
			cap rm `tmp'
			qui shell sh -c 'ps -p `pid' >/dev/null 2>&1 && touch `tmp''
			
			cap confirm file `tmp'
			if !_rc {
				noi di "Waiting for background jobs to end..."
				sleep `=1000*60*`WAIT_TIME_MINS''				
			}
			else local check_cpus = 0
		}
		if !mi("`pid_from_dobatch_stata_pid'") global DOBATCH_STATA_PID ""
	}
	
	* Return parameter values
	return scalar WAIT_TIME_MINS = `WAIT_TIME_MINS'	

end

** EOF
