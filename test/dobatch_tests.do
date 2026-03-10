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

* Test batch execution with resource monitoring disabled
global DOBATCH_WAIT_TIME_MINS = 0
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do
dobatch dofile1.do

* Test resource monitoring with short wait time
global DOBATCH_WAIT_TIME_MINS = 0.1
global DOBATCH_MAX_STATA_JOBS = 8
dobatch dofile1.do
global DOBATCH_MAX_STATA_JOBS = 12

* dobatch_wait default: wait until all Stata procs finish (requires nobody else using Stata!)
rm test1.log
dobatch dofile1.do
assert !mi("$DOBATCH_STATA_PID")
dobatch_wait
assert mi("$DOBATCH_STATA_PID")
confirm file test1.log

* specify a specific PID
rm test1.log
dobatch dofile1.do
local pid = r(PID)
assert !mi(`pid')
assert !mi("$DOBATCH_STATA_PID")
dobatch_wait, pid(`pid')
assert !mi("$DOBATCH_STATA_PID")
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

* exe(): filename only (looked up in Stata installation directory / PATH)
if c(os)=="Windows" {
	rm test1.log
	dobatch dofile1.do, exe("StataMP-64.exe")
	dobatch_wait
	confirm file test1.log
}

* exe(): full absolute path
if c(os)=="Windows" {
	rm test1.log
	dobatch dofile1.do, exe("`c(sysdir_stata)'StataMP-64.exe")
	dobatch_wait
	confirm file test1.log
}

* exe(): invalid name should produce an error
cap dobatch dofile1.do, exe("nonexistent_stata.exe")
assert _rc==601

* Test DOBATCH_DISABLE mode
global DOBATCH_DISABLE = 1
dobatch dofile1.do
global DOBATCH_DISABLE

* Unix-only: expanding ~ to user's home directory
* Note: for this example to work, the /dobatch folder must be placed in user's home directory
if c(os)=="Unix" {
	rm test1.log
	dobatch "~/dobatch/test/dofile1.do"
	sleep 8000
	confirm file test1.log
}
** EOF
