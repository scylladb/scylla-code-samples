General Info and Prerequisites
==============================

**This ansible playbook will install and configure ScyllaDB on all supported OS**
- RHEL7 / CentOS7 / Ubuntu 14.04 / Ubuntu 16.04 / Debian 8

**Prerequisites**
- [Ansible 2.3](http://docs.ansible.com/ansible/intro_installation.html)
- [Python 2.7](https://www.python.org/download/releases/2.7/)


Instructions and Usage Examples
===============================

**Note:** This playbook assumes you are installing ScyllaDB using the same disks and NIC for all nodes.


**1. Edit the 'hosts' and 'vars' in the yml file**
```
- hosts: [host_group_name_from_ini_file]   # e.g. 'scylla'
  become: yes                              # Run all tasks as root
  vars:
    release: 1.7                           # Scylla release to be installed
    cluster_name: cluster_name             # Use a unique cluster name
    seeds: IP/s of to-be seed_node/s       # Need at least 1 live seed node for new nodes to join the cluster (use 1:3 ratio)
    disks: /dev/sdb,/dev/sdc               # Disk names for raid0 creation, comma seperated
    NIC: eth0 / ens5 / bond1               # NIC to be used with optimized queue
```

**2. Edit the servers_example.ini file, add the IP/s of the hosts you wish to deploy on and name the host group**


**3. Run playbook on all hosts part of the group specified**
```
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook scylla_deployment.yml -i servers_example.ini
```

Using a vagrant machine? read more on [how to SSH into a Vagrant machine with Ansible](https://stackoverflow.com/questions/32748585/ssh-into-a-vagrant-machine-with-ansible?rq=1)



- *-t / --tags* only runs plays and tasks tagged with these values, 
for example, use *--tags=prereq,java* if you only wish to install java8 on Ubuntu14 / Debian.

- *--skip-tags* only runs plays and tasks whose tags do not match these values, 
for example, use *--skip-tags=conf,reboot* for the following purposes:
	- Install ScyllaDB on a client (loader), so to have Cassandra-stress tool available.
	- Install ScyllaDB on an intermediate node, as part of migration process, so to have ScyllaDB sstableloader tool available.

**4. List all facts collected by ansible, on all hosts, part of the group specified**
```
ansible -i servers_example.ini scylla -m setup | less
```
- To filter specific facts, for example ansible distribution, add -a flag
```
-a "filter=ansible_distribution*"
```


List of Tasks (and tags) in Playbook
====================================

```
ansible-playbook scylla_deployment.yml --list-tasks

playbook: scylla_deployment.yml
play #1 (host_group_name_from_ini_file): host_group_name_from_ini_file                        TAGS: []
tasks:
    Remove 'abrt' pkg from CentOS / RHEL                                                      TAGS: [prereq]
    Install epel-release and wget pkgs on CentOS / RHEL                                       TAGS: [prereq]
    Install add-apt-repository command utility on Debian / Ubuntu14                           TAGS: [prereq]
    Download Scylla {{ release }} repo for Centos 7 / RHEL 7                                  TAGS: [repo]
    Download Scylla {{ release }} repo for Ubuntu 14.04 (Trusty)                              TAGS: [repo]
    Download Scylla {{ release }} repo for Ubuntu 16.04 (Xenial)                              TAGS: [repo]
    Download Scylla {{ release }} repo for Debian 8 (Jessie)                                  TAGS: [repo]
    Add openjdk PPA to Ubuntu14 (prereq for Java 8)                                           TAGS: [java]
    Add openjdk PPA to Debian (prereq for Java 8)                                             TAGS: [java]
    Add Jessie-backports repo to Debian (prereq for Java 8)                                   TAGS: [java]
    Update apt cache on Debian / Ubuntu                                                       TAGS: [java]
    Install Java 8 on Ubuntu14, needed for Scylla release 1.7                                 TAGS: [java]
    Install Java 8 on Debian, needed for Scylla release 1.7                                   TAGS: [java]
    Update apt cache on Debian / Ubuntu                                                       TAGS: [install]
    Install scylla {{ release }} on Debian / Ubuntu                                           TAGS: [install]
    Install scylla {{ release }} on CentOS / RHEL                                             TAGS: [install]
    Select correct java version on Debian / Ubuntu14                                          TAGS: [conf]
    Configure Cluster name in yaml file                                                       TAGS: [conf]
    Configure seeds in yaml file                                                              TAGS: [conf]
    Configure listen address + rpc address in yaml file                                       TAGS: [conf]
    Run Scylla Setup (RAID-0, XFS format, NIC queue, disk IOtune), this may take a while      TAGS: [conf]
    Reboot server/s (required by Scylla)                                                      TAGS: [reboot]
    Wait for server/s to come up from boot                                                    TAGS: [reboot]
```
