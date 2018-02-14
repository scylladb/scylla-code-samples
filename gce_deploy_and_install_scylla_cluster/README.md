General Info and Prerequisites
==============================

**This script deploys 3 VMs on GCE and then installs and configures a Scylla cluster**
- VM defaults: n1-standard-2 with CentOS7 image and 2 SSD drives, 80GB storage per node, installed with latest Scylla 2.0 release
- Supported OS: RHEL7 / CentOS7 / Ubuntu 14.04 / Ubuntu 16.04 / Debian8


**Pre-requisites**
- [Google Cloud SDK](https://cloud.google.com/sdk/downloads)
- [Ansible 2.3](http://docs.ansible.com/ansible/intro_installation.html)
- [Python 2.7](https://www.python.org/download/releases/2.7/)



Instructions and Usage Examples
===============================

**How to run**
1. Download these 2 files
2. chmod the bash file to make it executable and run the script with the needed flag/s (or use the defaults)
3. Note the prerequisites which are mentioned also in the HELP output (``-h`` flag)

**Note:** For ease of use, run it from a GCE VM, as it comes with gcloud included and enables direct access to your GCP project.
The VM **must** have **full** Cloud API access (can be set only when VM is powered-off).

**Usage**

```
./gce_deploy_and_install_scylla_cluster.sh -h


Description
===========
This script deploys 3 VMs on GCE and creates a Scylla cluster
VM defaults: n1-standard-2 with CentOS 7 image and 2 SSD drives, 80GB storage per node


Prerequisites
=============
- Ansible 2.3: http://docs.ansible.com/ansible/latest/intro_installation.html
- Python 2.7: https://www.python.org/download/releases/2.7
- Google Cloud SDK: https://cloud.google.com/sdk/downloads
  Note: For ease of use, you should run this script from a GCE VM, as it comes with gcloud SDK included.
- The VM *MUST* have *FULL* access to all Cloud APIs (can be set only when VM is powered-off).


Usage
=====
-p   GCP project in which Scylla will be deployed (default: skilled-adapter-452). Usage: type '-p [MyProject]'
-z   Zone in which Scylla VMs will be deployed (default: us-east1-b). Usage: type '-z [Zone]'
-t   VM type (default: n1-standard-2). Example: to set n1-standard-8, type '-t n1-standard-8'
-s   SSD size in GB (default: 40), each VM has 2 SSD drives
-n   Use NVMe drives instead of SSD drives
-c   Number of NVMe drives (NVMe size: 375GB) to deploy per node (default: 2). Example: to deploy 4 drives, type '-c4'
-v   Scylla release to be installed (default: 2.0). Example: to set 1.7, type '-v1.7'

Select VM Image (default: CentOS 7)
-u   Ubuntu 16
-d   Debian 8
-r   RHEL 7
-b   Ubuntu 14

-h   Display this help and exit
```


**Examples**

Example1:
```
./gce_deploy_and_install_scylla_cluster.sh -t16 -n -c5 -v1.6
```
- This will deploy 3 VMs (n1-standard-16) with CentOS7 image and 5 NVMe drives per node, each 375GB. It will then install and configure the latest Scylla 1.6 release

Example2:
```
./gce_deploy_and_install_scylla_cluster.sh -t4 -s100 -u
```
- This will deploy 3 VMs (n1-standard-4) with Ubuntu16 image and 2 SSD drives per node, each 100GB. It will then then install and configure the latest Scylla 2.0 release

See Scylla releases [here](http://www.scylladb.com/category/users-blog/releases/).
