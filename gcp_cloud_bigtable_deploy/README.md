General Info and Prerequisites
==============================

This script deploys (4) VMs on GCE to be used as (8) YCSB loaders, it then deploys Cloud Bigtable instance on (20) nodes with YCSB schema.
Once deployment completes, a default 1TB dataset is populated using multiple YCSB loaders, after which various workloads are executed.
(Loader spec: n1-standard-8 with CentOS 7 image and 30GB boot disk)


Instructions and Usage Examples
===============================

**How to run**
1. Download the file
2. chmod the bash file to make it executable and run the script with the needed flag/s (or use the defaults)
3. Note the prerequisites which are mentioned also in the HELP output (``-h`` flag)

**Note:** For ease of use, run it from a GCE VM, as it comes with gcloud included and enables direct access to your GCP project.
The VM **must** have **full** Cloud API access (can be set only when VM is powered-off).

**Usage**

```
./gcp_cloud_bigtable_test.sh -h

Description
===========
This script deploys (4) VMs on GCE to be used as (8) YCSB loaders, it then deploys Cloud Bigtable instance on (20) nodes with YCSB schema.
Once deployment completes, a default 1TB dataset is populated using multiple YCSB loaders, after which various workloads are executed.
(Loader spec: n1-standard-8 with CentOS 7 image and 30GB boot disk)


Prerequsites
============
- Ansible 2.3 (or higher): http://docs.ansible.com/ansible/latest/intro_installation.html
- Python 2.7: https://www.python.org/download/releases/2.7
- Google Service Management API enabled --> go to https://console.developers.google.com/apis/library/servicemanagement.googleapis.com/?project=[your_project_id]
- Google Cloud Resource Manager API enabled --> go to https://console.developers.google.com/apis/library/cloudresourcemanager.googleapis.com/?[your_project_id]
- Cloud Bigtable Admin API enabled --> go to https://console.developers.google.com/apis/library/bigtableadmin.googleapis.com/?project=[your_project_id]
- Create your google cloud json auth key --> see instructions here: https://cloud.google.com/docs/authentication/getting-started
- Google Cloud SDK: https://cloud.google.com/sdk/download
  Note: For ease of use, you should run this script from a GCE VM, as it comes with gcloud SDK included.
- The VM *MUST* have *FULL* access to all Cloud APIs (can be set only when VM is powered-off).


Usage
=====
-p   GCP project in which the VMs will be deployed (default: skilled-adapter-452) --> Type '-p [MyProject]'
-z   Zone in which the loaders and Cloud BigTable instance will be deployed (default: us-east1-b --> Type '-z [Zone]'
-n   Number of VMs to deploy (default: 4)
-t   VM type (default: n1-standard-8) | Example: for 'n1-standard-4' --> type '-t n1-standard-4'
-s   Boot disk size in GB (default: 30)
-b   Number of nodes for Cloud BigTable instance (default: 20)
-r   Number of records per loader (default: 125000000)
-h   Display this help and exit
```
