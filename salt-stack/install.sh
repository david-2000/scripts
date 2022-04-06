#!/bin/bash

# Date: 09-25-2021
# Author: David Pineda <david.pineda@my.wheaton.edu>
# This script will install the software necessary to run saltstack on the current host (both as a master and as a minion)
# References:
#	- https://repo.saltproject.io/#rhel

## Print string to stderr
function print_error()
{ echo -ne "ERROR: ${@}\n" >& 2 }


## Print Help and Usage message
function print_help()
{
	echo -e "This program can automate the installation and setup of salt-master and salt-minion."
	echo -e "Usage:"
	echo -e "\tOn salt master:"
	echo -e "\t\t${0} -M -m MASTER_IP_ADDRESS -v [7|8] -g GIT_URL -k SSH_KEY_PATH"
	echo -e "\tOn salt minion:"
	echo -e "\t\t${0} -m MASTER_IP_ADDRESS -v [7|8] -g GIT_URL [OPTIONS]"

	echo -e "Options:"
	echo -e "\t-f CONFIG_FILE\n\t\tA file that contains a list of parameters and values that override those provided through the command line."
	echo -e "\t-g GIT_ADDRESS\n\t\tDefine the remote git url to use as the source of custom state files."
	echo -e "\t-h\n\t\tPrint this help message."
	echo -e "\t-i PATH_TO_KEY\n\t\tLocation of the private ssh key to use for accessing the remote repositry."
	echo -e "\t-p PATH_TO_KEY\n\t\tLocation of the public ssh key published to the remote repositry."
	echo -e "\t-m MASTER_IP_ADDRESS\n\t\tWhat is the address|hostname of the salt master to connect to."
	echo -e "\t-M\n\t\tFlag to set the current host as the salt master. Will also set current host as a minion of itself."
	echo -e "\t-s VERSION_#\n\t\tFlag to set the version of salt stack to install."
	echo -e "\t-v VERSION_#\n\t\tFlag to set the version of RHEL that the host is running."
}

## Parse command-line arguments
function parse_args()
{

	## Some variables|flags come with default values
	local opt
	while getopts ":hm:g:v:Mfp:i:f:s:" opt; do
		case ${opt} in 
			f) ## Config File with parameters.
				CONFIG="${OPTARG}"
				;;
			g) ## Address of the git repository to use for highstate.
				GIT_URL="${OPTARG}"
				;;
			h) ## Print usage information
				print_help
				exit 0
				;;
			i) ## Provide a custom path to the private ssh-key
				PRIV_KEY="${OPTARG}"
				;;
			p) ## Provide a custom path to the public ssh-key
				PUB_KEY="${OPTARG}"
				;;
			m) ## Master IP address or hostname
				MASTER_IP="${OPTARG}"
				;;
			M) ## Master flag -- current host is the salt-master
				IAMMASTER=true
				;;
			v) ## RHEL Version
				RHEL_VERSION=$OPTARG
				;;
			s) ## SALT Version
				SALT_VERSION=$OPTARG
				;;
			:) ## Required argument not provided
				print_error "${OPTARG} needs a parameter."
				exit
				;;
			\?) ## Not a recognized option
				print_error "${OPTARG} is not a recognized option."
				print_error "Run \"${0} -h\" for usage info."
				;;

		esac
	done
	shift $((OPTIND-1))
	
	## Script must run as root to be able to do update, setup and config
	test "$USER" != "root" && print_error "Script must be run as root!." && exit 1

	test ! -z "${CONFIG}" && test ! -e "${CONFIG}" && print_error "${CONFIG} does not exist." && exit 1
	test ! -z "${CONFIG}" && test -e "${CONFIG}" && echo -e "Loading ${CONFIG} parameters. Command line arguments will be ignored." && . ${CONFIG}

	## Check that required parameters are set
	test -z "${MASTER_IP}" && print_error "Missing required -m [MASTER_IP_ADDRESS] flag." && exit 1
	test -z "${RHEL_VERSION}" && print_error "Must provide the hosts RHEL version. Use the -v VERSION flag." && exit 1
	test -z "${SALT_VERSION}" && print_error "Must provide the SALT version to install. Use the -s VERSION flag." && exit 1
	
	curl -fsSL https://repo.saltproject.io/py3/redhat/${RHEL_VERSION}/$(uname -m)/${SALT_VERISON}/SALTSTACK-GPG-KEY.pub || print_error "Could not import gpg key" && exit 1
	curl -fsSL https://repo.saltproject.io/py3/redhat/${RHEL_VERSION}/$(uname -m)/${SALT_VERSION}.repo || print_error "Could not find a salt v${SALT_VERSION} repo for RHEL ${RHEL_VERSION}" && exit 1

	## Check that we can reach the salt-master
	ping -c 1 "${MASTER_IP}" >> /dev/null
	if [ $? != 0 ] ; then 
		print_error "Cannot establish connection to salt-master."
		print_error "Host ${MASTER_IP} unreachable with ping."
		exit 1
	fi


	## If the host is to be the salt-master, provide required arguments
	if [ ! -z $IAMMASTER ] ; then
		# Set up ssh-keys
		test -z "$PRIV_KEY" && print_error "$PRIV_KEY does not exist!" && exit 1
		test -z "$PUB_KEY" && print_error "$PRIV_KEY does not exist!" && exit 1
		test ! -d '/root/.ssh' && mdkir '/root/.ssh' && chmod 600 '/root/.ssh'
		echo -e "Host github.com\n  User git\n  HostName github.com\n  IdentityFile ${PRIV_KEY}" >> '/root/.ssh/config'
		
		## Ensure that the right permissions are set for both keys
		chmod 600 $PRIV_KEY
		chmod 644 $PUB_KEY

		## Need to provide the url to use for fileserver config
		test -z $GIT_URL && print_error "You must provide a github url for the gitfs configuration." && exit 1
		test [ "$(git ls-remote --exit-code -h $GIT_URL)" == "" ] && print_error "Could not ping the remote repository [$GIR_URL]. Check the repo address and verify that the provided keys match." && exit 1
	fi
}


## Configure the salt-master specifically.
function salt_master_config()
{
	## Install pygit2 for the gitfs
	yum install -y epel-release

	## Running on a RHEL 7
	if [ "$RHEL_VERSION" == "7" ] ; then
		yum install -y python-pygit2
		yum install -y libgit2{,-devel}
		/usr/bin/pip3 install pygit2==1.5.0 # It would be great if I could get around having to use this.
	## Running on a RHEL 8
	elif [ "$RHEL_VERSION" == "8" ] ; then
		dnf install -y python3-pygit2 libgit2
	fi
	

	## Salt fileserver conf
	echo -e "file_roots:\n  base:\n    - /srv/salt" > /etc/salt/master.d/fileserver.conf
	echo -e "fileserver_backend:\n  - gitfs\n  - roots\n" >> /etc/salt/master.d/fileserver.conf
	echo -e "gitfs_provider: pygit2\n" >> /etc/salt/master.d/fileserver.conf
	echo -e "gitfs_remotes:\n  - ssh://$GIT_URL:" >> /etc/salt/master.d/fileserver.conf
	echo -e "      - pubkey: ${PUB_KEY}" >> /etc/salt/master.d/fileserver.conf
	echo -e "      - privkey: ${PRIV_KEY}" >> /etc/salt/master.d/fileserver.conf
	echo -e "      - root: salt" >> /etc/salt/master.d/fileserver.conf
	
	## Salt fileserver conf
	echo -e "ext_pillar:\n  - git:\n    - ssh://master ${GIT_URL}:" > /etc/salt/master.d/pillar.conf
	echo -e "      - pubkey: ${PUB_KEY}" >> /etc/salt/master.d/pillar.conf
	echo -e "      - privkey: ${PRIV_KEY}" >> /etc/salt/master.d/pillar.conf
	echo -e "      - root: pillar\n" >> /etc/salt/master.d/pillar.conf
	echo -e "git_pillar_provider: pygit2" >> /etc/salt/master.d/pillar.conf


	## Allow incomming minion trafic 
	firewall-cmd --add-service=salt-master --permanent
	firewall-cmd --add-port=4505/tcp --permanent
	firewall-cmd --add-port=4506/tcp --permanent
	firewall-cmd --reload
	systemctl enable salt-master && systemctl start salt-master
	salt-run fileserver.update

}


## Configure the salt-minion specifically.
function salt_minion_config()
{
	## Initial minion config file is empty. 'Remove' it so that 
	## our custom file in the minion.d directory is used to find the salt-master
	mv /etc/salt/minion{,.bak}
	echo "master: ${MASTER_IP}" > /etc/salt/minion.d/master.conf
	systemctl enable salt-minion && systemctl start salt-minion

}


## Main Function. 
function main ()
{
	parse_args $@
	
	## ----------------------------------------------
	## INSTALL PREREQUISITES
	## ----------------------------------------------

	## Ensure machine is up to date
	yum update -y ; yum upgrade -y

	## Install some usefull packages
	packages="git vim python3 python3-devel"
	yum install -y $packages

	## Setup python3 virtual_env
	python3 -m venv --system-site-packages /usr/local/python3_env
	echo 'export PATH=/usr/local/python3_env/bin:$PATH' > /etc/profile.d/python3_env.sh
	/usr/local/python3_env/bin/pip3 install --upgrade pip

	## ----------------------------------------------
	## INSTALL SALTSTACK
	## ----------------------------------------------

	## Install Saltstack Repository and key
	sudo rpm --import https://repo.saltproject.io/py3/redhat/${RHEL_VERSION}/$(uname -m)/${SALT_VERISON}/SALTSTACK-GPG-KEY.pub || print_error "Could not import gpg key" && exit 1
	curl -fsSL https://repo.saltproject.io/py3/redhat/${RHEL_VERSION}/$(uname -m)/${SALT_VERSION}.repo | sudo tee /etc/yum.repos.d/salt.repo
	yum clean expire-cache

	# Only install salt-master if specifically requested for
	test ! -z $IAMMASTER && yum install -y salt-master
	## Install salt-master, salt-minion, and other components
	yum install -y salt-{minion,ssh,syndic,cloud,api}

	## Enable and start salt services
	systemctl enable salt-syndic && systemctl start salt-syndic
	systemctl enable salt-api && systemctl start salt-api


	## ----------------------------------------------
	## CONFIGURE SALTSTACK
	## ----------------------------------------------
	test ! -z $IAMMASTER && salt_master_config
	salt_minion_config

}



main $@
