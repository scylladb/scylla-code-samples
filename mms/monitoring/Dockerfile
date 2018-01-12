FROM centos
RUN yum update;yum -y install git wget fontconfig urw-fonts initscripts
WORKDIR /opt
RUN git clone https://github.com/scylladb/scylla-grafana-monitoring.git --depth=1
RUN wget -q https://github.com/prometheus/prometheus/releases/download/v2.0.0/prometheus-2.0.0.linux-amd64.tar.gz; tar xf prometheus-2.0.0.linux-amd64.tar.gz
RUN wget -q https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana;rpm --import RPM-GPG-KEY-grafana
RUN wget -q https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-4.6.3-1.x86_64.rpm; rpm -Uvh grafana-4.6.3-1.x86_64.rpm
RUN cp /opt/scylla-grafana-monitoring/prometheus/* /opt/prometheus-2.0.0.linux-amd64/

WORKDIR /opt/prometheus-2.0.0.linux-amd64
RUN sed -i 's/\/etc\/scylla.d\/prometheus/\/opt\/prometheus-2.0.0.linux-amd64/g' prometheus.yml
RUN sed -i 's/- 172.17.0.2:9180//' scylla_servers.yml;sed -i '/172.17.0.2/c\' node_exporter_servers.yml
RUN echo "- 'scylla-node1:9180'" >> scylla_servers.yml;echo "  - 'scylla-node1:9180'" >> node_exporter_servers.yml
RUN echo "  - 'scylla-node2:9180'" >> scylla_servers.yml;echo "  - 'scylla-node2:9180'" >> node_exporter_servers.yml
RUN echo "  - 'scylla-node3:9180'" >> scylla_servers.yml; echo "  - 'scylla-node3:9180'" >> node_exporter_servers.yml
RUN mkdir /opt/prometheus-2.0.0.linux-amd64/mydata

ADD start.sh /
RUN chmod +x /start.sh
CMD /start.sh