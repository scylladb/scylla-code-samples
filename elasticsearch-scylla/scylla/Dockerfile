FROM ubuntu:16.04
ADD start.sh /
RUN apt-get update;apt-get install -y wget dnsutils
RUN wget -O /etc/apt/sources.list.d/scylla.list http://downloads.scylladb.com/deb/ubuntu/scylla-1.7-xenial.list
RUN apt-get update;apt-get install -y scylla-server scylla-jmx scylla-tools --force-yes
RUN sed -i 's/listen_address:/#listen_address:/i' /etc/scylla/scylla.yaml
RUN sed -i 's/endpoint_snitch:/#endpoint_snitch:/i' /etc/scylla/scylla.yaml
RUN sed -i 's/rpc_address:/#rpc_address:/i' /etc/scylla/scylla.yaml
CMD bash /start.sh
