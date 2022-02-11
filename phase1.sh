#!/usr/bin/env bash
#
# Phase 1 - Prepare the infrastrucutre.
#


### Validate settings.
source Settings

echo "

IMPORTANT
This script uses the values defined in the 'Settings' file.
Feel free to adjust the values to your needs.

These are the current values for your reference:

LIBVIRT_URI=$LIBVIRT_URI
#LIBVIRT_STORAGE=$LIBVIRT_STORAGE
LIBVIRT_NETWORK_PREFIX=$LIBVIRT_NETWORK_PREFIX
LIBVIRT_STORAGE_POOL_BASE=$LIBVIRT_STORAGE_POOL_BASE

CLUSTER_DOMAIN=$CLUSTER_DOMAIN
CLUSTER_NAME=$CLUSTER_NAME
CLUSTER_VERSION=$CLUSTER_VERSION
DISCONNECTED=$DISCONNECTED

Do you want to continue? Press Enter or CTRL+C to abort."

#read tmp


### Check for sudo privileges

sudo id 2>&1 1>/dev/null
if [ $? -eq 0 ]; then
	echo "INFO: User has sudo privileges."
else
	echo "WARNING: User DOES NOT have sudo privileges without password."
fi


### Verify libvirt is enabled
if [ $(sudo systemctl is-enabled libvirtd.service) != 'enabled' ] ; then
  echo "Error: Libvirt is not enabled."
  exit -1
else
  echo "INFO: Libvirt installed and enabled."
fi

### Check for needed binaries.
packages=""

virsh -v 2>&1 1>/dev/null
if [ $? -eq 0 ]; then
	echo "INFO: virsh detected."
else
  packages="$packages libvirt-client"
fi

virt-install --version 2>&1 1>/dev/null
if [ $? -eq 0 ]; then
	echo "INFO: virt-install detected."
else
  packages="$packages virt-install"
fi

virt-viewer --version 2>&1 1>/dev/null
if [ $? -eq 0 ]; then
	echo "INFO: virt-viewer detected."
else
  packages="$packages virt-viewer"
fi

if [ "$packages" != "" ] ; then
  echo "INFO: Installing missing virt packages..."
  sudo dnf install -y $packages
fi


### Connect to system instance of libvirt.
sudo virsh connect qemu:///system


# Create network for cluster.
if [ "$(sudo virsh net-list --all --name | grep $CLUSTER_NAME)" != "" ] ; then
    echo "INFO: Network already exists."
else
    if [ $DISCONNECTED ] ; then
        xml=$(eval "echo \"$(cat files.phase1/virt-network-isolated.xml)\"")
    else
        xml=$(eval "echo \"$(cat files.phase1/virt-network-nat.xml)\"")
    fi
    echo $xml > /tmp/network-tmp.xml

    sudo virsh net-define --file /tmp/network-tmp.xml
    sudo virsh net-autostart $CLUSTER_NAME
    sudo virsh net-start $CLUSTER_NAME
    rm /tmp/network-tmp.xml
fi

# Create the storage pool for the cluster.
if [ "$(sudo virsh pool-list --all --name | grep $CLUSTER_NAME)" != "" ] ; then
    echo "INFO: Storage Pool already exists."
else
    mkdir -p $LIBVIRT_STORAGE_POOL_BASE/$CLUSTER_NAME
    sudo virsh pool-create-as --print-xml --name $CLUSTER_NAME --type dir --target $LIBVIRT_STORAGE_POOL_BASE/$CLUSTER_NAME > /tmp/pool-tmp.xml
    sudo virsh pool-define --file /tmp/pool-tmp.xml
    sudo virsh pool-autostart $CLUSTER_NAME
    sudo virsh pool-start $CLUSTER_NAME
    rm /tmp/pool-tmp.xml
fi
