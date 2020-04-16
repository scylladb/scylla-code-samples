# scylla-check-gossiper-generation

This is a checker required to run before upgrades on all long-running nodes. 

### Usage:

On an operational Scylla node, with working `nodetool` available run

`./scylla-check-gossiper-generation.sh`

The output will advise on whether the user should get in touch with Scylla support before proceeding with an upgrade. 
