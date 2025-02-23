* This script runs a series of tests on the -dobatch- package
* Author: Julian Reif

clear
adopath ++"../src"
set more off
version 18
program drop _all

cap rm test1.log
cap rm test1_myarg.log
cap rm test2.log

global DOBATCH_MIN_CPUS_AVAILABLE
global DOBATCH_MAX_STATA_JOBS
global DOBATCH_WAIT_TIME_MINS

if c(os)=="Windows" {
	
	global DOBATCH_DISABLE = 0
	rcof noi dobatch dofile1.do
	assert _rc==198
	
	global DOBATCH_DISABLE = 1
	dobatch dofile1.do
}

else {
	global DOBATCH_WAIT_TIME_MINS = 0
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do

	global DOBATCH_WAIT_TIME_MINS = 0.1
	global DOBATCH_MAX_STATA_JOBS = 8
	dobatch dofile1.do
	global DOBATCH_MAX_STATA_JOBS = 12

	* dobatch_wait default: wait until all stata-mp procs finish (requires nobody else using stata-mp!)
	rm test1.log
	dobatch dofile1.do
	dobatch_wait
	confirm file test1.log
	
	* specify a specific PID
	rm test1.log
	dobatch dofile1.do
	local pid = r(PID)
	assert !mi(`pid')
	dobatch_wait, pid(`pid')
	confirm file test1.log
	
	* Ensure that supplying arguments works
	dobatch dofile1.do "myarg"
	dobatch_wait
	confirm file test1_myarg.log
	
	global DOBATCH_MAX_STATAJOBS = 1
	dobatch dofile1.do

	* Add error handling for options such as , nostop
	dobatch dofile2.do
	sleep 1000
	cap confirm file test2.log
	assert _rc==601

	dobatch dofile2.do, nostop
	sleep 1000
	confirm file test2.log
	
	assert r(MAX_STATA_JOBS)==12
}
** EOF

