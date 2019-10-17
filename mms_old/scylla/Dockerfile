FROM ubuntu:16.04
ADD start.sh /
RUN apt-get update;apt-get install -y wget dnsutils apt-transport-https
RUN wget -O /etc/apt/sources.list.d/scylla.list http://repositories.scylladb.com/scylla/repo/c9b1cee446693faf5c4e0f13ab88f854/ubuntu/scylladb-2.1-xenial.list
RUN apt-get update;apt-get install -y scylla-server scylla-jmx scylla-tools --force-yes
RUN sed -i 's/listen_address:/#listen_address:/i' /etc/scylla/scylla.yaml
RUN sed -i 's/endpoint_snitch:/#endpoint_snitch:/i' /etc/scylla/scylla.yaml
RUN sed -i 's/rpc_address:/#rpc_address:/i' /etc/scylla/scylla.yaml
ADD mutant-data.txt /
CMD bash /start.sh
