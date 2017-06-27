General info and prerequisites
==============================

This ansible script will deploy, install and configure ScyllaDB on all supported OS.
- RHEL7
- Centos7
- Ubuntu 14.04
- Ubuntu 16.04
- Debian 8

Prerequisites:
- Ansible 2.3
- Python 2.7


Instructions
============

This playbook assumes you are installing Scylla using the same disks and NIC for all nodes


Running all tasks all host group: ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook scylla_deployment.yml -i servers.ini
 -t / --tags only runs plays and tasks tagged with these values
 --skip-tags only runs plays and tasks whose tags do not match these values


List all tasks: ansible-playbook scylla_deployment.yml --list-tasks

playbook: scylla_deployment.yml
 play #1 (host_group_name_from_ini_file): host_group_name_from_ini_file                        TAGS: []
   tasks:
     Remove 'abrt' pkg from CentOS / RHEL                                                      TAGS: [1_prereq]
     Install epel-release and wget pkgs on CentOS / RHEL                                       TAGS: [1_prereq]
     Update apt cache on Debian / Ubuntu                                                       TAGS: [1_prereq]
     Install add-apt-repository command utility on Debian / Ubuntu14                           TAGS: [1_prereq]
     Add openjdk PPA to Ubuntu14 (prereq for Java 8)                                           TAGS: [2_java]
     Add openjdk PPA to Debian (prereq for Java 8)                                             TAGS: [2_java]
     Add Jessie-backports repo to Debian (prereq for Java 8)                                   TAGS: [2_java]
     Update apt cache on Debian / Ubuntu                                                       TAGS: [2_java]
     Install Java 8 on Ubuntu14, needed for Scylla release 1.7                                 TAGS: [2_java]
     Install Java 8 on Debian, needed for Scylla release 1.7                                   TAGS: [2_java]
     Select correct java version on Debian / Ubuntu14                                          TAGS: [2_java]
     Download Scylla {{ release }} repo for Centos 7 / RHEL 7                                  TAGS: [3_repo]
     Download Scylla {{ release }} repo for Ubuntu 14.04 (Trusty)                              TAGS: [3_repo]
     Download Scylla {{ release }} repo for Ubuntu 16.04 (Xenial)                              TAGS: [3_repo]
     Download Scylla {{ release }} repo for Debian 8 (Jessie)                                  TAGS: [3_repo]
     Install scylla {{ release }} on Debian / Ubuntu                                           TAGS: [4_install]
     Install scylla {{ release }} on CentOS / RHEL                                             TAGS: [4_install]
     Configure Cluster name in yaml file                                                       TAGS: [5_conf]
     Configure seeds in yaml file                                                              TAGS: [5_conf]
     Configure listen address + rpc address in yaml file                                       TAGS: [5_conf]
     Run Scylla Setup (RAID-0, XFS format, NIC queue, disk IOtune), this may take a while      TAGS: [5_conf]
     Reboot server/s (required by Scylla)                                                      TAGS: [6_reboot]
     Wait for server/s to come up from boot                                                    TAGS: [6_reboot]


List all facts collected by ansible, on the host group: ansible -i servers.ini servers -m setup | less
To filter specific facts use: -a "filter=ansible_distribution*"

