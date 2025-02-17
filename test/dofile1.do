local arg1 "`1'"


* Sleep for 5 seconds
sleep 5000

log using test1.log, replace

sysuse auto, clear

log close

if !mi("`arg1'") {
	log using test1_`arg1'.log
	sysuse auto, clear
	log close
}

** EOF

