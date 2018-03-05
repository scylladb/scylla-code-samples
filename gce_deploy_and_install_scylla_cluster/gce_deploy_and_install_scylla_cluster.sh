#!/bin/bash
#
#  Copyright (C) 2017 ScyllaDB


## Variables ##
PROJECT="skilled-adapter-452"
ZONE="us-east1-b"
VM_TYPE="n1-standard-2"
SSD_SIZE="40"
SSD=YES
NVME_NUM="2"
VM_NUM="3"
RELEASE="2.0"
CENTOS7="--image "centos-7-v20180104" --image-project "centos-cloud""
U16="--image "ubuntu-1604-xenial-v20180122" --image-project "ubuntu-os-cloud""
U14="--image "ubuntu-1404-trusty-v20180122" --image-project "ubuntu-os-cloud""
DEB8="--image "debian-8-jessie-v20180109" --image-project "debian-cloud""
RH7="--image "rhel-7-v20180104" --image-project "rhel-cloud""
VM_OS="$CENTOS7"
TIMESTAMP=`date "+%m-%d--%H%M"`


while getopts ":hnudrbp:c:z:v:s:t:" opt; do
	case $opt in
		h)  echo ""
		    echo ""
		    echo "Description"
		    echo "==========="
		    echo "This script deploys 3 VMs on GCE and creates a Scylla cluster"
		    echo "VM defaults: n1-standard-2 with CentOS 7 image and 2 SSD drives, 80GB storage per node"
		    echo ""
		    echo ""
		    echo "Prerequisites"
		    echo "============="
		    echo "- Ansible 2.3: http://docs.ansible.com/ansible/latest/intro_installation.html"
		    echo "- Python 2.7: https://www.python.org/download/releases/2.7"
                    echo "- Google Cloud SDK: https://cloud.google.com/sdk/downloads"
                    echo "  Note: For ease of use, you should run this script from a GCE VM, as it comes with gcloud SDK included."
                    echo "- The VM *MUST* have *FULL* access to all Cloud APIs (can be set only when VM is powered-off)."
		    echo ""
		    echo ""
		    echo "Usage"
		    echo "====="
                    echo "-p   GCP project in which Scylla will be deployed (default: $PROJECT). Usage: type '-p [MyProject]'"
                    echo "-z   Zone in which Scylla VMs will be deployed (default: $ZONE). Usage: type '-z [Zone]'"
		    echo "-t   VM type (default: $VM_TYPE). Example: to set n1-standard-8, type '-t n1-standard-8'"
		    echo "-s   SSD size in GB (default: 40), each VM has 2 SSD drives"
		    echo "-n   Use NVMe drives instead of SSD drives"
		    echo "-c   Number of NVMe drives (NVMe size: 375GB) to deploy per node (default: $NVME_NUM). Example: toםdeploy 4 drives, type '-c4'"
                    echo "-v   Scylla release to be installed (default: 2.0). Example: to set 1.7, type '-v1.7'"
		    echo ""
		    echo "Select VM Image (default: CentOS 7)"
		    echo "-u   Ubuntu 16"
		    echo "-d   Debian 8"
		    echo "-r   RHEL 7"
		    echo "-b   Ubuntu 14"
		    echo ""
		    echo "-h   Display this help and exit"
		    echo ""
		    echo ""
		    exit 2
		    ;;
		p)  PROJECT=$OPTARG ;;
		z)  ZONE=$OPTARG ;;
		s)  SSD_SIZE=$OPTARG ;;
		c)  NVME_NUM=$OPTARG ;;
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


VER=`echo $RELEASE | sed s/\\\./-/g`


# Create 6 SSD drives, 40GB each (2 per node)
if [ $SSD == "YES" ]; then
	echo ""
	echo ""
	echo "### Creating disks in '$ZONE' zone: 6 SSD drives, $SSD_SIZE GB each"
	gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-1-ssd-1" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
	echo ""
	echo "### `whoami`-$TIMESTAMP-ansible-1-ssd-1 created"
        gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-1-ssd-2" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
        echo "### `whoami`-$TIMESTAMP-ansible-1-ssd-2 created"
        gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-2-ssd-1" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
        echo "### `whoami`-$TIMESTAMP-ansible-2-ssd-1 created"
        gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-2-ssd-2" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
        echo "### `whoami`-$TIMESTAMP-ansible-2-ssd-2 created"
        gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-3-ssd-1" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
        echo "### `whoami`-$TIMESTAMP-ansible-3-ssd-1 created"
        gcloud compute disks create "`whoami`-$TIMESTAMP-ansible-3-ssd-2" --size "$SSD_SIZE" --type "pd-ssd" --zone "$ZONE" &> /dev/null
        echo "### `whoami`-$TIMESTAMP-ansible-3-ssd-2 created"


# Create 3 CentOS7 VMs, boot disk 20GB, each VM with 2 SSD drives, 80GB storage
	echo ""
	echo ""
	echo "### Creating 3 VMs ($VM_TYPE) in '$ZONE' zone | 20GB boot disk | $SSD_SIZE GB SSD drive x 2"
	echo "### $VM_OS"
	echo ""
	gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-1" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=`whoami`-$TIMESTAMP-ansible-1-ssd-1,device-name=`whoami`-$TIMESTAMP-ansible-1-ssd-1,mode=rw,boot=no,auto-delete=yes" --disk "name=`whoami`-$TIMESTAMP-ansible-1-ssd-2,device-name=`whoami`-$TIMESTAMP-ansible-1-ssd-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-1"
	gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-2" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=`whoami`-$TIMESTAMP-ansible-2-ssd-1,device-name=`whoami`-$TIMESTAMP-ansible-2-ssd-1,mode=rw,boot=no,auto-delete=yes" --disk "name=`whoami`-$TIMESTAMP-ansible-2-ssd-2,device-name=`whoami`-$TIMESTAMP-ansible-2-ssd-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-2"
	gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-3" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" --disk "name=`whoami`-$TIMESTAMP-ansible-3-ssd-1,device-name=`whoami`-$TIMESTAMP-ansible-3-ssd-1,mode=rw,boot=no,auto-delete=yes" --disk "name=`whoami`-$TIMESTAMP-ansible-3-ssd-2,device-name=`whoami`-$TIMESTAMP-ansible-3-ssd-2,mode=rw,boot=no,auto-delete=yes" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-3"

else

# Create 3 CentOS7 VMs, boot disk 20GB, each VM with 2 NVMe drives, 750GB storage
        echo ""
	echo ""
        echo "### Creating 3 VMs ($VM_TYPE) in '$ZONE' zone | 20GB boot disk | 375GB NVMe drive x $NVME_NUM"
	echo "### $VM_OS"
        echo ""
	gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-1" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-1" `myString=$(printf "%$NVME_NUM"s);echo ${myString// /'--local-ssd interface=NVME' }`
        gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-2" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-2" `myString=$(printf "%$NVME_NUM"s);echo ${myString// /'--local-ssd interface=NVME' }`
        gcloud compute --project "$PROJECT" instances create "`whoami`-$TIMESTAMP-scylla-$VER-ansible-3" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --tags "http-server","https-server" $VM_OS --boot-disk-size "20" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ansible-3" `myString=$(printf "%$NVME_NUM"s);echo ${myString// /'--local-ssd interface=NVME' }`

fi


# Allow VMs network to come-up before installing Scylla with Ansible
echo ""
echo ""
echo "### Waiting 45 sec for VMs network to start (it may linger), prior to Scylla installation"
echo ""
sleep 45


# Generate servers.ini file for Ansible
echo ""
echo "### Creating inventory file (servers.ini) with VMs external IP addresses"
echo ""
echo "[scylla]" > servers.ini
gcloud compute instances describe `whoami`-$TIMESTAMP-scylla-$VER-ansible-1 --zone "$ZONE" | grep -i natip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini
gcloud compute instances describe `whoami`-$TIMESTAMP-scylla-$VER-ansible-2 --zone "$ZONE" | grep -i natip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini
gcloud compute instances describe `whoami`-$TIMESTAMP-scylla-$VER-ansible-3 --zone "$ZONE" | grep -i natip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini


# Update Scylla release in playbook yml file
echo ""
echo "### Setting Scylla $RELEASE release in playbook yml file"
echo ""


# Update seed node IP in playbook yml file
NEW=`gcloud compute instances describe "$(whoami)"-$TIMESTAMP-scylla-$VER-ansible-1 --zone "$ZONE" | grep -i networkip | cut -d ":" -f2 | awk '{$1=$1};1'`
echo ""
echo "### Setting $NEW as seed node IP in playbook yml file"
echo ""
sed -e s/seedIP/$NEW/g -e s/scyllaVer/$RELEASE/g scylla_install_orig.yml > scylla_install_new.yml


# Update cluster name in playbook yml file
echo ""
echo "### Setting unique cluster name in playbook yml file"
echo ""
sed -i -e s/gce_ansible_cluster/gce_ansible_cluster_$TIMESTAMP/g scylla_install_new.yml


# Update NIC to ens5 (Ubuntu16) in playbook yml file vars
if [ "$VM_OS" == "$U16" ]; then
	echo ""
	echo "### Ubuntu 16 image, setting NIC to 'ens5' in playbook yml file"
	echo ""
	sed -i -e s/eth0/ens5/g scylla_install_new.yml
fi


# Update disks names (NVMe) in playbook yml file vars
if [ "$SSD" == "NO" ]; then
	echo ""
	echo "### NVMe drives, updating disks names in playbook yml file"
	echo ""
	for i in `seq 1 $NVME_NUM`; do DISK=$DISK"/dev/nvme0n$i,"; done
	x=`echo "$DISK" | sed 's/,$//'`
	sed -i -e s~\/dev\/sdb,\/dev\/sdc~$x~g scylla_install_new.yml
fi


# Run Ansible script using generated servers.ini file and the playbook yml file
sed -i -e 's/^/#/' ~/.ssh/known_hosts
echo ""
echo "### Installing Scylla $RELEASE cluster using Ansible playbook"
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook scylla_install_new.yml -i servers.ini


# End message
echo ""
echo "### Your Scylla cluster should be up and running. Login to one of the nodes and run 'nodetool status'"
echo "### Note: it may take up to 1 min. for all nodes to join the ring"
echo ""
echo ""
