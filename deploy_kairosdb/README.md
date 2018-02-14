General Info and Prerequisites
==============================

This script deploys and configures KairosDB as a time series frontend for Scylla


**Pre-requisites**
- [Ansible site](http://docs.ansible.com/ansible/intro_installation.html)
- [Install Ansible 2.3 (or higher)](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-ansible-on-ubuntu-16-04)
- [Scylla cluster up and running](https://www.scylladb.com/download/)


Instructions
============

**How to run**
1. Download the file
2. Set variables in kairosdb_deploy.yml file:
	- Scylla node/s IP
	- Number of shards per node that Scylla utilizes (```cat /etc/scylla.d/cpuset.conf```)


**Run the playbook**
 - Run locally: add ‘localhost ansible_connection=local’ entry in /etc/ansible/hosts file
 - Run on remote nodes: add an entry of each node’s IP in /etc/ansible/hosts file
 - ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook kairosdb_deploy.yml
