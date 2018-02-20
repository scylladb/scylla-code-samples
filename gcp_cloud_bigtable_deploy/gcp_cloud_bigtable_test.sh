#!/bin/bash
#
#  Copyright (C) 2018 ScyllaDB


## Variables ##
TIMESTAMP=`date "+%m-%d"`
PROJECT="skilled-adapter-452"
ZONE="us-east1-b"
VM_TYPE="n1-standard-8"
NUM_VM="4"
BOOT_DISK="30"
CENTOS7="--image "centos-7-v20180104" --image-project "centos-cloud""
VM_OS="$CENTOS7"
BTABLE_INSTANCE="`whoami`-instance-$TIMESTAMP"
BTABLE_CLUSTER="`whoami`-instance-cluster-$TIMESTAMP"
BTABLE_NODE="20"
totalloaders=$(( $NUM_VM*2 ))
numofrecs="125000000"
totalpartitions=$(( $numofrecs*$totalloaders )) # Calculate the number of total partitions to be written
lastinrng=-$numofrecs
filecnt=1



while getopts ":hp:z:s:n:t:b:r:" opt; do
	case $opt in
		h)  echo ""
		    echo "Description"
		    echo "==========="
		    echo "This script deploys ($NUM_VM) VMs on GCE to be used as ($totalloaders) YCSB loaders, it then deploys Cloud Bigtable instance on ($BTABLE_NODE) nodes with YCSB schema."
		    echo "Once deployment completes, a default 1TB dataset is populated using multiple YCSB loaders, after which various workloads are executed."
		    echo "(Loader spec: $VM_TYPE with CentOS 7 image and 30GB boot disk)"
		    echo ""
		    echo ""
		    echo "Prerequsites"
		    echo "============"
		    echo "- Ansible 2.3 (or higher): http://docs.ansible.com/ansible/latest/intro_installation.html"
		    echo "- Python 2.7: https://www.python.org/download/releases/2.7"
		    echo "- Google Service Management API enabled --> go to https://console.developers.google.com/apis/library/servicemanagement.googleapis.com/?project=[your_project_id]"
		    echo "- Google Cloud Resource Manager API enabled --> go to https://console.developers.google.com/apis/library/cloudresourcemanager.googleapis.com/?[your_project_id]"
		    echo "- Cloud Bigtable Admin API enabled --> go to https://console.developers.google.com/apis/library/bigtableadmin.googleapis.com/?project=[your_project_id]"
		    echo "- Create your google cloud json auth key --> see instructions here: https://cloud.google.com/docs/authentication/getting-started"
		    echo "- Google Cloud SDK: https://cloud.google.com/sdk/download"
		    echo "  Note: For ease of use, you should run this script from a GCE VM, as it comes with gcloud SDK included."
		    echo "- The VM *MUST* have *FULL* access to all Cloud APIs (can be set only when VM is powered-off)."
		    echo ""
		    echo ""
		    echo "Usage"
		    echo "====="
                    echo "-p   GCP project in which the VMs will be deployed (default: $PROJECT) --> Type '-p [MyProject]'"
                    echo "-z   Zone in which the loaders and Cloud BigTable instance will be deployed (default: $ZONE --> Type '-z [Zone]'"
		    echo "-n   Number of VMs to deploy (default: $NUM_VM)"
		    echo "-t   VM type (default: $VM_TYPE) | Example: for 'n1-standard-4' --> type '-t n1-standard-4'"
		    echo "-s   Boot disk size in GB (default: $BOOT_DISK)"
		    echo "-b   Number of nodes for Cloud BigTable instance (default: $BTABLE_NODE)"
		    echo "-r   Number of records per loader (default: $numofrecs)"
		    echo "-h   Display this help and exit"
		    echo ""
		    exit 2
		    ;;
		p)  PROJECT=$OPTARG ;;
		z)  ZONE=$OPTARG ;;
		s)  BOOT_DISK=$OPTARG ;;
		n)  NUM_VM=$OPTARG ;;
		t)  VM_TYPE=$OPTARG ;;
		b)  BTABLE_NODE=$OPTARG ;;
		r)  numofrecs=$OPTARG ;;
		\?)  echo "Invalid option: -$OPTARG"
		    exit 2
		    ;;
		:)  echo "Option -$OPTARG requires an argument."
		    exit 2
		    ;;
	esac
done



# Create 4 CentOS7 VMs with 30GB boot disk
echo ""
echo "### Creating $NUM_VM VMs ($VM_TYPE) in '$ZONE' zone | $BOOT_DISK GB boot disk"
echo "### $VM_OS"
echo ""

for ((i=1;i<=NUM_VM;i++)); do
	gcloud beta compute --project "$PROJECT" instances create "`whoami`-ycsb-$TIMESTAMP-loader-$i" --zone "$ZONE" --machine-type "$VM_TYPE" --network "default" --maintenance-policy "MIGRATE" --service-account "$PROJECT@appspot.gserviceaccount.com" --scopes "https://www.googleapis.com/auth/cloud-platform" --min-cpu-platform "Automatic" --tags "http-server","https-server" --image "centos-7-v20180104" --image-project "centos-cloud" --boot-disk-size "$BOOT_DISK" --boot-disk-type "pd-ssd" --boot-disk-device-name "`whoami`-ycsb-$TIMESTAMP-Loader-$i"
	gcloud beta compute --project "$PROJECT" instances add-labels `whoami`-ycsb-$TIMESTAMP-loader-$i --labels=keep=alive,keep-alive=keep-alive
done
echo ""



# Allow VMs network to come-up before installing Maven + YCSB with Ansible
echo ""
echo "### Waiting 30 sec for VM/s network to start"
sleep 30
echo ""



# Generate servers.ini file for Ansible
echo ""
echo "### Creating inventory file (servers.ini) of the local_vm + loaders IPs"
echo ""
echo "[loaders]" > servers.ini
for ((i=1;i<=NUM_VM;i++)); do
	gcloud compute instances describe `whoami`-ycsb-$TIMESTAMP-loader-$i --zone "$ZONE" | grep -i natip | cut -d ":" -f2 | awk '{$1=$1};1' >> servers.ini
done
echo "" >> servers.ini
echo "[local_vm]" >> servers.ini
sudo ifconfig | grep -i inet | awk 'NR==1' | awk '{$1=$1};1' | awk '{print $2}' >> servers.ini



# Run Ansible commands on the servers.ini IP list
sed -i -e 's/^/#/' /home/`whoami`/.ssh/known_hosts
echo ""
echo "### Installing WGET on loaders"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'yum install -y -q wget'
echo ""


echo "### Installing JAVA on local_vm + loaders"
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'cd /opt; wget -q --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jdk-8u161-linux-x64.tar.gz"'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'cd /opt; tar xzf jdk-8u161-linux-x64.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'cd /opt/jdk1.8.0_161; alternatives --install /usr/bin/java java /opt/jdk1.8.0_161/bin/java 2; alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_161/bin/jar 2; alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_161/bin/javac 2'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'alternatives --set jar /opt/jdk1.8.0_161/bin/jar; alternatives --set javac /opt/jdk1.8.0_161/bin/javac'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'export JAVA_HOME=/opt/jdk1.8.0_161; export JRE_HOME=/opt/jdk1.8.0_161/jre; export PATH=$PATH:/opt/jdk1.8.0_161/bin:/opt/jdk1.8.0_161/jre/bin'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/environment state=present line='export JAVA_HOME=/opt/jdk1.8.0_161' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/environment state=present line='export JRE_HOME=/opt/jdk1.8.0_161/jre' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/environment state=present line='export PATH=$PATH:/opt/jdk1.8.0_161/bin:/opt/jdk1.8.0_161/jre/bin' create=yes insertafter=EOF"
echo ""
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'cd /opt; wget -q --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jdk-8u161-linux-x64.tar.gz"'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'cd /opt; tar xzf jdk-8u161-linux-x64.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'cd /opt/jdk1.8.0_161; alternatives --install /usr/bin/java java /opt/jdk1.8.0_161/bin/java 2; alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_161/bin/jar 2; alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_161/bin/javac 2'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'alternatives --set jar /opt/jdk1.8.0_161/bin/jar; alternatives --set javac /opt/jdk1.8.0_161/bin/javac'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'export JAVA_HOME=/opt/jdk1.8.0_161; export JRE_HOME=/opt/jdk1.8.0_161/jre; export PATH=$PATH:/opt/jdk1.8.0_161/bin:/opt/jdk1.8.0_161/jre/bin'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/environment state=present line='export JAVA_HOME=/opt/jdk1.8.0_161' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/environment state=present line='export JRE_HOME=/opt/jdk1.8.0_161/jre' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/environment state=present line='export PATH=$PATH:/opt/jdk1.8.0_161/bin:/opt/jdk1.8.0_161/jre/bin' create=yes insertafter=EOF"
echo ""
echo ""


echo ""
echo "### Installing MAVEN on local_vm + loaders"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'wget -q http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'tar xzf apache-maven-3.5.2-bin.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'mv apache-maven-3.5.2/ /opt/maven'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'ln -s /opt/maven/bin/mvn /usr/bin/mvn'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='#!/bin/bash' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='MAVEN_HOME=/opt/maven' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='PATH=$MAVEN_HOME/bin:$PATH' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='export PATH MAVEN_HOME' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='export CLASSPATH=.' create=yes insertafter=EOF"
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'chmod +x /etc/profile.d/maven.sh'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders -u `whoami` -m shell -a 'source /etc/profile.d/maven.sh'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'rm -f apache-maven-3.5.2-bin.tar.gz'
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'wget -q http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'tar xzf apache-maven-3.5.2-bin.tar.gz'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'mv apache-maven-3.5.2/ /opt/maven'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'ln -s /opt/maven/bin/mvn /usr/bin/mvn'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='#!/bin/bash' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='MAVEN_HOME=/opt/maven' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='PATH=$MAVEN_HOME/bin:$PATH' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='export PATH MAVEN_HOME' create=yes insertafter=EOF"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m lineinfile -a "dest=/etc/profile.d/maven.sh state=present line='export CLASSPATH=.' create=yes insertafter=EOF"
echo ""
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'chmod +x /etc/profile.d/maven.sh'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm -u `whoami` -m shell -a 'source /etc/profile.d/maven.sh'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini local_vm --become -m shell -a 'rm -f apache-maven-3.5.2-bin.tar.gz'
echo ""


echo "### Installing GIT on loaders"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'yum install -y -q git'
echo ""


echo "### Clone YCSB to loaders with prepared statements (used by Scylla/C*/Yogabyte)"
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'git clone https://github.com/brianfrankcooper/YCSB.git'
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'cd YCSB; git remote add robertpang https://github.com/robertpang/YCSB.git; sudo git fetch -q robertpang; sudo git merge -q robertpang/i458 -m "prepared statements support"'
echo ""


echo "### Building all YCSB bindings on loaders, this may take up to 10 min."
ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini loaders --become -m shell -a 'cd YCSB; mvn clean -q -B package'
echo ""



# Create a Cloud Bigtable instance with YCSB table
echo "### Installing local Cloud SDK for Cloud Bigtable"
sudo yum install -y -q google-cloud-sdk google-cloud-sdk-bigtable-emulator
sudo yum makecache -y -q && sudo yum update -y -q kubectl google-cloud-sdk google-cloud-sdk-datastore-emulator google-cloud-sdk-pubsub-emulator google-cloud-sdk-app-engine-go google-cloud-sdk-app-engine-java google-cloud-sdk-app-engine-python google-cloud-sdk-cbt google-cloud-sdk-bigtable-emulator google-cloud-sdk-datalab
sudo sed -i -e 's/true/false/' /usr/lib64/google-cloud-sdk/lib/googlecloudsdk/core/config.json
#gcloud config set project $PROJECT
#gcloud config set account `whoami`@scylladb.com
echo ""
echo ""


echo "### Creating a Cloud Bigtable instance"
gcloud beta bigtable instances create $BTABLE_INSTANCE --cluster=$BTABLE_CLUSTER --cluster-zone=$ZONE --cluster-num-nodes=$BTABLE_NODE --description=Bigtable_for_YCSB_load
echo ""
echo ""


echo "### Cloning cloud-bigtable-examples repo"
cd ~
git clone https://github.com/GoogleCloudPlatform/cloud-bigtable-examples.git
echo ""
echo ""


echo "### Creating a table for YCSB load using HBase shell"
cd cloud-bigtable-examples/quickstart
chmod +x quickstart.sh
echo "create 'usertable', 'cf', {SPLITS => (1..200).map {|i| \"user\#{1000+i*(9999-1000)/200}\"}}" | ./quickstart.sh
#echo 'create 'usertable', 'cf', {SPLITS => (1..200).map {|i| "user#{1000+i*(9999-1000)/200}"}}' | ./quickstart.sh
echo""
echo""



# Generate loader files
echo "### Generating loader files for YCSB population and workloads"

lastinrng=-$numofrecs
filecnt=1
for ((i=1;i<$totalpartitions;i+=$numofrecs))
{
lastinrng=$(( $lastinrng+$numofrecs ));
outfile="ycsb_populate-$filecnt.sh";
echo '#!/bin/sh' > $outfile;
echo "" >> $outfile;
echo "nohup sudo ~/YCSB/bin/ycsb load googlebigtable -p columnfamily=cf -p google.bigtable.project.id=$PROJECT -p google.bigtable.instance.id=$BTABLE_INSTANCE -p google.bigtable.auth.json.keyfile=[full_path_to_json_file] -p recordcount=$totalpartitions -p operationcount=$totalpartitions -p insertstart=$lastinrng -p insertcount=$numofrecs -s -P workloads/workloada -threads 100 > populate-$filecnt.dat &" >> $outfile;
((filecnt++));
}


lastinrng=-$numofrecs;
filecnt=1;
for ((i=1;i<$totalpartitions;i+=$numofrecs))
{
lastinrng=$(( $lastinrng+$numofrecs ));
outfile="ycsb_workloada-$filecnt.sh";
echo '#!/bin/sh' > $outfile;
echo "" >> $outfile;
echo "nohup sudo ~/YCSB/bin/ycsb run googlebigtable -p columnfamily=cf -p google.bigtable.project.id=$PROJECT -p google.bigtable.instance.id=$BTABLE_INSTANCE -p google.bigtable.auth.json.keyfile=[full_path_to_json_file] -p recordcount=$totalpartitions -p operationcount=$numofrecs -p insertstart=$lastinrng -p insertcount=$numofrecs -p maxexecutiontime=1800 -s -P workloads/workloada -threads 30 > workloada-$filecnt.dat &" >> $outfile;
((filecnt++));
}


lastinrng=-$numofrecs;
filecnt=1;
for ((i=1;i<$totalpartitions;i+=$numofrecs))
{
lastinrng=$(( $lastinrng+$numofrecs ));
outfile="ycsb_workloadb-$filecnt.sh";
echo '#!/bin/sh' > $outfile;
echo "" >> $outfile;
echo "nohup sudo ~/YCSB/bin/ycsb run googlebigtable -p columnfamily=cf -p google.bigtable.project.id=$PROJECT -p google.bigtable.instance.id=$BTABLE_INSTANCE -p google.bigtable.auth.json.keyfile=[full_path_to_json_file] -p recordcount=$totalpartitions -p operationcount=$numofrecs -p insertstart=$lastinrng -p insertcount=$numofrecs -p maxexecutiontime=1800 -s -P workloads/workloadb -threads 30 > workloadb-$filecnt.dat &" >> $outfile;
((filecnt++));
}


lastinrng=-$numofrecs;
filecnt=1;
for ((i=1;i<$totalpartitions;i+=$numofrecs))
{
lastinrng=$(( $lastinrng+$numofrecs ));
outfile="ycsb_workloadc-$filecnt.sh";
echo '#!/bin/sh' > $outfile;
echo "" >> $outfile;
echo "nohup sudo ~/YCSB/bin/ycsb run googlebigtable -p columnfamily=cf -p google.bigtable.project.id=$PROJECT -p google.bigtable.instance.id=$BTABLE_INSTANCE -p google.bigtable.auth.json.keyfile=[full_path_to_json_file] -p recordcount=$totalpartitions -p operationcount=$numofrecs -p insertstart=$lastinrng -p insertcount=$numofrecs -p maxexecutiontime=1800 -s -P workloads/workloadc -threads 30 > workloadc-$filecnt.dat &" >> $outfile;
((filecnt++));
}


lastinrng=-$numofrecs;
filecnt=1;
for ((i=1;i<$totalpartitions;i+=$numofrecs))
{
lastinrng=$(( $lastinrng+$numofrecs ));
outfile="ycsb_workloadd-$filecnt.sh";
echo '#!/bin/sh' > $outfile;
echo "" >> $outfile;
echo "nohup sudo ~/YCSB/bin/ycsb run googlebigtable -p columnfamily=cf -p google.bigtable.project.id=$PROJECT -p google.bigtable.instance.id=$BTABLE_INSTANCE -p google.bigtable.auth.json.keyfile=[full_path_to_json_file] -p recordcount=$totalpartitions -p operationcount=$numofrecs -p insertstart=$lastinrng -p insertcount=$numofrecs -p maxexecutiontime=1800 -s -P workloads/workloadd -threads 30 > workloadd-$filecnt.dat &" >> $outfile;
((filecnt++));
}

chmod 777 ycsb_*
echo ""
echo ""


echo "### SUCCESS: YCSB loaders are up. Cloud Bigtable with YCSB schema created. 8 YCSB loader files created"
echo ""
echo ""


echo "### What to do next?"
echo "### Copy each pair of files to 1 loader. Copy your json auth key (see prerequisites) to all loaders and specify its path in the loader files."
echo "### Run the population, wait for it to complete, and then run the workloads"
echo ""
echo ""


echo "### To grep the relevant strings out of each workload output files, run the following:"
echo "### Throughput: less [output_file] | grep -i through"
echo "### Operations: less [output_file] | grep -i operations,"
echo "### 95th latency: less [output_file] | grep -i 95th"
echo "### 99th latency: less [output_file] | grep -i 99th"
echo "### MAX latency: less [output_file] | grep -i maxl"
echo ""
echo ""

#scp -p ycsb_* `whoami`@[to_each_loader]:~/YCSB

#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a 'scp -p ycsb_* `whoami`@35.231.47.182:~/YCSB'


#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
#ANSIBLE_HOST_KEY_CHECKING=False ansible -i servers.ini -u `whoami` -m shell -a ''
