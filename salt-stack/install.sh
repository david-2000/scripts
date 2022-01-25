#!/bin/bash

# Date: 09-25-2021
# Author: David Pineda <david.pineda@my.wheaton.edu>
# This script will install the software necessary to run saltstack on the current host (both as a master and as a minion)
# References:
#	- https://repo.saltproject.io/#rhel

## Print a string to stderr
function print_err() { echo -e "ERROR: ${@}" >&2 }


## Print usage information and exit
function help()
{
	echo -e "This program can automate the installation and setup of salt-master and salt-minion."
	echo -e "This program can automate the installation and setup of salt-master and salt-minion."
	echo -e "Usage:"
	echo -e "\tOn salt master:"
	echo -e "\t\t${0} -M [-f CONFIG_FILE] [-m MASTER_IP_ADDRESS] [-v [7|8]] [-g GIT_URL] [-k SSH_KEY_PATH]"
	echo -e "\tOn salt minion:"
	echo -e "\t\t${0} -W [-f CONFIG_FILE] [-m MASTER_IP_ADDRESS] [-v [7|8]] [-g GIT_URL] [OPTIONS]"

	echo -e "Options:"
	echo -e "\t-f CONFIG_FILE\n\t\tPath to the config file containing configurations. Any parameters not passed in as arguments in the command line must be specified within the file. By default, this will be set to the script's current working directory."
	echo -e "\t-g GIT_ADDRESS\n\t\tDefine the remote git url to use as the source of custom state files."
	echo -e "\t-h\n\t\tPrint this help message."
	echo -e "\t-k SSH_KEY_PATH\n\t\tUse SSH_KEY_PAYH to find ssh keys to use for connecting to remote repo. The keys will be copied to /root/.ssh/"
	echo -e "\t-m MASTER_IP_ADDRESS\n\t\tWhat is the address|hostname of the salt master to connect to."
	echo -e "\t-M\n\t\tFlag to set the current host as the salt master. Will also set current host as a minion of itself."
	echo -e "\t-W\n\t\tFlag to set the current host as a salt minion."
	echo -e "\t-v VERSION_#\n\t\tFlag to set the version of RHEL that the host is running."

}
