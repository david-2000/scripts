#!/bin/bash

## Script will set up a virtualenv for python that pip3 packages will be installed to.
## And ensure that the path to virtualenv is in PATH for all users.

## Main Function
function main()
{
	get_opts $@

}


function get_opts()
{
	local opt
	while getopts "d:" opt; do
		case ${opt} in
			d)
				VDIR="$OPTARG"
				;;
			:) ## Missing required arg
				;;
			\?) ## Not recognized
				;;
		esac
	done
	shift $(($OPTIND-1))
	
	echo -e "$VDIR"
}


main $@
