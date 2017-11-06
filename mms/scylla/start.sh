#!/bin/bash
FILE='/configured.txt'
IP=`ip addr | grep eth0  | tail -n1 | cut -d ' ' -f 6 | cut -d '/' -f 1`

if [ ! -f "$FILE" ]
then
  sed -i "s/seeds: \"127.0.0.1\"/seeds: \"$SEEDS\"/g" /etc/scylla/scylla.yaml

  if [ -n "${DC1}" ]; then
  echo 'dc=DC1' > /etc/scylla/cassandra-rackdc.properties
  fi

  if [ -n "${DC2}" ]; then
  echo 'dc=DC2' > /etc/scylla/cassandra-rackdc.properties
  fi
 echo 'prefer_local=true' >> /etc/scylla/cassandra-rackdc.properties
 echo 'rack=Rack1' >> /etc/scylla/cassandra-rackdc.properties
 echo 'endpoint_snitch: GossipingPropertyFileSnitch' >> /etc/scylla/scylla.yaml
 echo 'listen_address: ' $IP >> /etc/scylla/scylla.yaml
 echo 'rpc_address: ' $IP >> /etc/scylla/scylla.yaml
 echo 'start_native_transport: true' >> /etc/scylla/scylla.yaml
touch /configured.txt

fi

export SCYLLA_CONF='/etc/scylla'
/usr/bin/scylla --developer-mode 1 --options-file /etc/scylla/scylla.yaml&
/usr/lib/scylla/jmx/scylla-jmx -l /usr/lib/scylla/jmx&
sleep infinity
