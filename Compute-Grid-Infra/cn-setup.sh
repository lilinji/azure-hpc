#!/bin/bash
export MOUNT_POINT=/mnt/azure

# Shares
SHARE_HOME=/share/home
SHARE_SCRATCH=/share/scratch
NFS_ON_MASTER=/data
NFS_MOUNT=/data

# User
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

#############################################################################
log()
{
	echo "$1"
}

usage() { echo "Usage: $0 [-m <masterName>] [-s <pbspro>] [-q <queuename>] [-S <beegfs, nfsonmaster>]" 1>&2; exit 1; }

while getopts :m:S:s:q: optname; do
  log "Option $optname set with value ${OPTARG}"
  
  case $optname in
    m)  # master name
		export MASTER_NAME=${OPTARG}
		;;
    S)  # Shared Storage (beegfs, nfsonmaster)
		export SHARED_STORAGE=${OPTARG}
		;;
    s)  # Scheduler (pbspro)
		export SCHEDULER=${OPTARG}
		;;
    q)  # queue name
		export QNAME=${OPTARG}
		;;
	*)
		usage
		;;
  esac
done


mount_nfs()
{
	log "install NFS"

	yum -y install nfs-utils nfs-utils-lib
	
	mkdir -p ${NFS_MOUNT}

	log "mounting NFS on " ${MASTER_NAME}
	showmount -e ${MASTER_NAME}
	mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
	
	echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail  0 0" >> /etc/fstab
}

install_beegfs_client()
{
	bash install_beegfs.sh ${MASTER_NAME} "client"
}

install_ganglia()
{
	bash install_ganglia.sh ${MASTER_NAME} "Cluster" 8649
}

install_pbspro()
{
	bash install_pbspro.sh ${MASTER_NAME} ${QNAME}
}

install_blobxfer()
{
	yum install -y gcc openssl-devel libffi-devel python-devel
	curl https://bootstrap.pypa.io/get-pip.py | python
	pip install --upgrade blobxfer
}

setup_user()
{
	yum -y install nfs-utils nfs-utils-lib

    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_SCRATCH

	echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
	mount -a
	mount
   
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

    chown $HPC_USER:$HPC_GROUP $SHARE_SCRATCH	
}

SETUP_MARKER=/var/local/cn-setup.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

# disable selinux
sed -i 's/enforcing/disabled/g' /etc/selinux/config
setenforce permissive

setup_user
install_ganglia

if [ "$SCHEDULER" == "pbspro" ]; then
	install_pbspro
fi

if [ "$SHARED_STORAGE" == "beegfs" ]; then
	install_beegfs_client
elif [ "$SHARED_STORAGE" == "nfsonmaster" ]; then
	mount_nfs
fi

install_blobxfer
# Create marker file so we know we're configured
touch $SETUP_MARKER

shutdown -r +1 &
exit 0
