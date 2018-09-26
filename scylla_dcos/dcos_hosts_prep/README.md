# Host preparation for DC/OS Agents to run Scylla nodes

This playbook will prepare a set of hosts provided via an ansible inventory, to run containerized Scylla nodes.

The playbook covers:
 - disk preparation
 - disk and net tuning
 - firewall configuration

At the end of the play, a __cpuset__ is printed per host.
The __cpuset__ should be used when creating Scylla containers

## Tunables and variables

- disks: List of disks for Scylla to use. The disks will be cleared and gathered into a RAID-0
- array_name: Name of the array to create (default "md0")
- filesystem: Filesystem type to create, recommended default is "xfs"
- mountpoint: Mountpoint where the created array will be mounted
- mount_opts: Mount options for the Scylla array. Recommended defaults are 'noatime,nofail,defaults'
- overwrite_disk: If overwrite_disk is set to false, and mkfs fails, the execution will stop. Setting to "true" is destructive.
- host_if: Interface of the hosts which will be used to map Scylla services
- prereqs: List of RPM prerequisites
- scylla_ports: List of ports to open on the hosts


## Running the playbook

`ansible-playbook -i inventory.inv dcos_scylla_agent_prep.yml`
