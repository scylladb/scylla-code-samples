#!/bin/bash
#
#  Copyright (C) 2017 ScyllaDB


## Variables ##
DISK_NUM="2"
DISK_SIZE="40"
SSD=YES
VM_NUM="3"
VM_TYPE="2"
RELEASE="1.7"
CENTOS7="--image "centos-7-v20170719" --image-project "centos-cloud""
U16="--image "ubuntu-1604-xenial-v20170803" --image-project "ubuntu-os-cloud""
U14="--image "ubuntu-1404-trusty-v20170807" --image-project "ubuntu-os-cloud""
DEB8="--image "debian-8-jessie-v20170717" --image-project "debian-cloud""
RH7="--image "rhel-7-v20170719" --image-project "rhel-cloud""
VM_OS="$CENTOS7"


while getopts ":hnudrbv:s:t:" opt; do
	case $opt in
		h)  echo ""
		    echo "This script deploys 3 VMs on GCE and creates a Scylla cluster"
		    echo "VM defaults: n1-standard-2 with CentOS 7 image and 2 SSD drives, 80GB storage per node"
		    echo ""
		    echo "Pre-requisites:"
		    echo "- Google Cloud SDK: https://cloud.google.com/sdk/download"
		    echo "- Ansible 2.3: http://docs.ansible.com/ansible/latest/intro_installation.html"
		    echo "- Python 2.7: https://www.python.org/download/releases/2.7"
		    echo ""
		    echo "For ease of use, run it from a GCE VM, as it comes with gcloud included. The VM needs to have"
		    echo "Cloud API access scopes: Allow full access to all Cloud APIs (can be set only when VM is powered-off)"
		    echo ""
		    echo "Usage:"
		    echo "-t   Set VM type (default: n1-standard-2). Example: to set n1-standard-4, type '4'"
		    echo "-s   Set SSD size in GB (default: 40), each VM has 2 SSD drives"
		    echo "-n   Use 2 local NVMe drives (NVMe size: 375GB) per node, instead of 2 SSD drives"
                    echo "-v   Scylla release to be installed (default: 1.7). Example: to set 1.6, type '1.6'"
		    echo ""
		    echo "Select VM Image (default: CentOS7):"
		    echo "-u   Deploy VMs with Ubuntu 16 image"
		    echo "-d   Deploy VMs with Debian 8 image"
		    echo "-r   Deploy VMs with RHEL 7 image"
		    echo "-b   Deploy VMs with Ubuntu 14 image"
		    echo ""
		    echo "-h   Display this help and exit"
		    echo ""
		    exit 2
		    ;;
		s)  DISK_SIZE=$OPTARG ;;
		t)  VM_TYPE=$OPTARG ;;
		v)  RELEASE=$OPTARG ;;
		n)  SSD=NO ;;
		u)  VM_OS=$U16 ;;
		d)  VM_OS=$DEB8 ;;
		r)  VM_OS=$RH7 ;;
		b)  VM_OS=$U14 ;; 
		\?)  echo "Invalid option: -$OPTARG"
		    exit 2
		    ;;
		:)  echo "Option -$OPTARG requires an argument."
		    exit 2
		    ;;
	esac
done


# Create 6 SSD drives, 40GB each (2 per node)
if [ $SSD == "YES" ]; then
	echo ""
	echo "### Creating disks: 6 SSD drives, $DISK_SIZE GB each"
	echo ""
	gcloud compute disks create "ansible-inst-1-disk-1" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-1-disk-1 created"
	gcloud compute disks create "ansible-inst-1-disk-2" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-1-disk-2 created"
	gcloud compute disks create "ansible-inst-2-disk-1" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-2-disk-1 created"
	gcloud compute disks create "ansible-inst-2-disk-2" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-2-disk-2 created"
	gcloud compute disks create "ansible-inst-3-disk-1" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-3-disk-1 created"
	gcloud compute disks create "ansible-inst-3-disk-2" --size "$DISK_SIZE" --type "pd-ssd" --zone "us-east1-b" &> /dev/null
	echo "### ansible-inst-3-disk-2 created"

# Create 3 CentOS7 VMs, boot disk 20GB, each VM with 2 SSD drives, 80GB storage
	echo ""
	echo "### Creating 3 VMs (n1-standard-$VM_TYPE) | 20GB boot disk | $DISK_SIZE GB SSD drive x 2"
	echo "### $VM_OS"
	echo ""
	gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-1" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=ansible-inst-1-disk-1,device-name=ansible-inst-1-disk-1,mode=rw,boot=no,auto-delete=yes" --disk "name=ansible-inst-1-disk-2,device-name=ansible-inst-1-disk-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-1"
	gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-2" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=ansible-inst-2-disk-1,device-name=ansible-inst-2-disk-1,mode=rw,boot=no,auto-delete=yes" --disk "name=ansible-inst-2-disk-2,device-name=ansible-inst-2-disk-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-2"
	gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-3" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=ansible-inst-3-disk-1,device-name=ansible-inst-3-disk-1,mode=rw,boot=no,auto-delete=yes" --disk "name=ansible-inst-3-disk-2,device-name=ansible-inst-3-disk-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-3"

else

# Create 3 CentOS7 VMs, boot disk 20GB, each VM with 2 NVMe drives, 750GB storage
        echo ""
        echo "### Creating 3 VMs (n1-standard-$VM_TYPE) | 20GB boot disk | 375GB NVMe drive x 2"
	echo "### $VM_OS"
        echo ""
	gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-1" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --local-ssd interface="NVME" --local-ssd interface="NVME" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-1"
        gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-2" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --local-ssd interface="NVME" --local-ssd interface="NVME" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-2"
        gcloud compute --project "skilled-adapter-452" instances create "ansible-inst-3" --zone "us-east1-b" --machine-type "n1-standard-$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "skilled-adapter-452@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --local-ssd interface="NVME" --local-ssd interface="NVME" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "ansible-inst-3"

fi


# Allow VMs network to come-up before installing Scylla with Ansible
echo ""
echo ""
echo "### Waiting 20 sec for VMs network to come up (sometime it lingers), prior to Scylla installation"
echo ""
sleep 20


# Generate servers.ini file for Ansible
echo ""
echo "### Creating inventory file (servers.ini) with VMs internal IP addresses"
echo ""
echo "[scylla]" > servers.ini
gcloud compute instances describe ansible-inst-1 --zone "us-east1-b" | grep -i networkip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini
gcloud compute instances describe ansible-inst-2 --zone "us-east1-b" | grep -i networkip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini
gcloud compute instances describe ansible-inst-3 --zone "us-east1-b" | grep -i networkip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini


# Update Scylla release in playbook yml file
echo ""
echo "### Updating Scylla $RELEASE release in playbook yml file"
echo ""
sed s/scyllaVer/$RELEASE/g scylla_install_orig.yml > scylla_install_new.yml


# Update seed node IP in playbook yml file
NEW=`gcloud compute instances describe ansible-inst-1 --zone "us-east1-b" | grep -i networkip | cut -d ":" -f2 | awk '{$1=$1};1'`
echo ""
echo "### Updating seed node IP: $NEW in playbook yml file"
echo ""
sed -i s/seedIP/$NEW/g scylla_install_new.yml


# Update NIC to ens5 (Ubuntu16) in playbook yml file vars
if [ "$VM_OS" == "$U16" ]; then
	echo ""
	echo "### Installing on Ubuntu 16, updating NIC value in playbook yml file to 'ens5'"
	echo ""
	sed -i s/eth0/ens5/g scylla_install_new.yml
fi


# Update disks names (NVMe) in playbook yml file vars
if [ "$SSD" == "NO" ]; then
	echo ""
	echo "### Using NVMe drives, updating disks names in playbook yml file"
	echo ""
	sed -i s/sdb/nvme0n1/g scylla_install_new.yml
	sed -i s/sdc/nvme0n2/g scylla_install_new.yml
fi


# Run Ansible script using generated servers.ini file and the playbook yml file
sed -i -e 's/^/#/' /home/`whoami`/.ssh/known_hosts
echo ""
echo "### Installing Scylla $RELEASE cluster using Ansible playbook"
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook scylla_install_new.yml -i servers.ini
echo ""
echo "### Your Scylla cluster should be up and running. Login to one of the node and run 'nodetool status'"
echo "### Note that it may take up to 1 min. for all nodes to join the ring"
echo ""
