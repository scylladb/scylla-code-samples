# scylla-check-gossiper-generation

This is a checker required to run before upgrades on all long-running nodes. 

*NOTE*: This script must be run on every node, it only checks the single current node, not the entire cluster. 

### Usage:

On an operational Scylla node, with working `nodetool` available run

`./scylla-check-gossiper-generation.sh`

The output will advise on whether the user should get in touch with Scylla support before proceeding with an upgrade. 
