General Info and Prerequisites
==============================

**This ansible script will deploy, install and configure ScyllaDB on all supported OS**
- RHEL7
- Centos7
- Ubuntu 14.04
- Ubuntu 16.04
- Debian 8

**Prerequisites**
- Ansible 2.3
- Python 2.7


Instructions and Usage Examples
===============================

This playbook assumes you are installing ScyllaDB using the same disks and NIC for all nodes.


**1. Edit the 'hosts' and 'vars' in the yml file - for example:**
```
hosts: [scylla] (host group name from ini file)
release: 1.7
cluster_name: cluster_name_example (use unique cluster name)
seeds: ip/s of to-be seed node/s (comma seperated)
# Need at least 1 live seed node for new nodes to join the cluster, ratio of seeds:scylla_cluster_nodes should be 1:3#
disks: /dev/sdb,/dev/sdc (disk names for raid0 creation, comma seperated)
NIC: eth0 / ens5 / bond1
```


**2. Edit the servers_example.ini file, add the IP/s of the hosts you wish to deploy on and name the host group**


**3. Running the playbook on all hosts, part of the group specified**
```
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook scylla_deployment.yml -i servers_example.ini
```

*-t / --tags* only runs plays and tasks tagged with these values
- use  *--tags=prereq,java*  if you only wish to install java8 on Ubuntu14 / Debian.

*--skip-tags* only runs plays and tasks whose tags do not match these values.
For example, use *--skip-tags=conf,reboot* for the following purposes:
- Install ScyllaDB on a client (loader), so to have access to Cassandra-stress tool
- Install ScyllaDB on an intermediate node, so to have access to the ScyllaDB sstableloader tool (for migration process)

**4. List all facts collected by ansible, on all hosts, part of the group specified**
```
ansible -i servers_example.ini scylla -m setup | less
```
- To filter specific facts use: *-a "filter=ansible_distribution**"



List of Tasks (and tags) in Playbook
====================================

**List all tasks and tags**
```
ansible-playbook scylla_deployment.yml --list-tasks

playbook: scylla_deployment.yml
play #1 (host_group_name_from_ini_file): host_group_name_from_ini_file                        TAGS: []
tasks:
    Remove 'abrt' pkg from CentOS / RHEL                                                      TAGS: [prereq]
    Install epel-release and wget pkgs on CentOS / RHEL                                       TAGS: [prereq]
    Update apt cache on Debian / Ubuntu                                                       TAGS: [prereq]
    Install add-apt-repository command utility on Debian / Ubuntu14                           TAGS: [prereq]
    Add openjdk PPA to Ubuntu14 (prereq for Java 8)                                           TAGS: [java]
    Add openjdk PPA to Debian (prereq for Java 8)                                             TAGS: [java]
    Add Jessie-backports repo to Debian (prereq for Java 8)                                   TAGS: [java]
    Update apt cache on Debian / Ubuntu                                                       TAGS: [java]
    Install Java 8 on Ubuntu14, needed for Scylla release 1.7                                 TAGS: [java]
    Install Java 8 on Debian, needed for Scylla release 1.7                                   TAGS: [java]
    Select correct java version on Debian / Ubuntu14                                          TAGS: [java]
    Download Scylla {{ release }} repo for Centos 7 / RHEL 7                                  TAGS: [repo]
    Download Scylla {{ release }} repo for Ubuntu 14.04 (Trusty)                              TAGS: [repo]
    Download Scylla {{ release }} repo for Ubuntu 16.04 (Xenial)                              TAGS: [repo]
    Download Scylla {{ release }} repo for Debian 8 (Jessie)                                  TAGS: [repo]
    Install scylla {{ release }} on Debian / Ubuntu                                           TAGS: [install]
    Install scylla {{ release }} on CentOS / RHEL                                             TAGS: [install]
    Configure Cluster name in yaml file                                                       TAGS: [conf]
    Configure seeds in yaml file                                                              TAGS: [conf]
    Configure listen address + rpc address in yaml file                                       TAGS: [conf]
    Run Scylla Setup (RAID-0, XFS format, NIC queue, disk IOtune), this may take a while      TAGS: [conf]
    Reboot server/s (required by Scylla)                                                      TAGS: [reboot]
    Wait for server/s to come up from boot                                                    TAGS: [reboot]
```
