# Running Scylla on DC/OS
This is a simple example of running Scylla optimized for performance on
[DC/OS](https://dcos.io).

## Host preparation
This repo contains an ansible [playbook](./dcos_hosts_prep/) which will prepare
the DC/OS Agent hosts for Scylla.

## Service template

This JSON can be used as a service template for i3.16xlarge.

The IPs in `"args"` and `"constraints"` have to be adjusted

The `"cpuset"` can be obtained by running the dcos_hosts_prep
playbook or by manually running
`perftune.py --nic eth0 --mode sq_split --tune net --get-cpu-mask|hex2list.py` on the hosts

Additional ports can be assigned, if needed, in the `portDefinitions` section.



```json
{
  "id": "/scylla001",
  "args": [
    "--overprovisioned",
    "0",
    "--seeds",
    "10.0.0.14",
    "--broadcast-address",
    "10.0.0.14",
    "--broadcast-rpc-address",
    "10.0.0.14",
    "--listen-address",
    "10.0.0.14",
    "--cpuset",
    "1-31,33-63"
  ],
  "backoffFactor": 1.15,
  "backoffSeconds": 1,
  "constraints": [
    [
      "hostname",
      "IS",
      "10.0.0.14"
    ]
  ],
  "container": {
    "type": "DOCKER",
    "volumes": [
      {
        "containerPath": "/var/lib/scylla/",
        "hostPath": "/scylla/",
        "mode": "RW"
      }
    ],
    "docker": {
      "image": "scylladb/scylla",
      "forcePullImage": true,
      "privileged": false,
      "parameters": []
    }
  },
  "cpus": 62,
  "disk": 0,
  "instances": 1,
  "maxLaunchDelaySeconds": 3600,
  "mem": 485000,
  "gpus": 0,
  "networks": [
    {
      "mode": "host"
    }
  ],
  "portDefinitions": [
    {
      "protocol": "tcp",
      "port": 9042
    },
    {
      "protocol": "tcp",
      "port": 9160
    },
    {
      "protocol": "tcp",
      "port": 7000
    },
    {
      "protocol": "tcp",
      "port": 7001
    },
    {
      "protocol": "tcp",
      "port": 10000
    }
  ],
  "requirePorts": false,
  "upgradeStrategy": {
    "maximumOverCapacity": 1,
    "minimumHealthCapacity": 1
  },
  "killSelection": "YOUNGEST_FIRST",
  "unreachableStrategy": {
    "inactiveAfterSeconds": 0,
    "expungeAfterSeconds": 0
  },
  "healthChecks": [],
  "fetch": []
}
```
