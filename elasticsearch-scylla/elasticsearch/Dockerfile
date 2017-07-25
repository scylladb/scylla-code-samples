FROM ubuntu
RUN apt-get update;apt-get install openjdk-8-jdk tar wget -y
RUN wget -q -O eleastic-search.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.0.0-alpha2.tar.gz
RUN tar xf eleastic-search.tar.gz -C /opt/
RUN useradd -s /bin/bash elasticsearch -d /home/elasticsearch -m
RUN chown -R elasticsearch:elasticsearch /opt/elasticsearch*
RUN sed -i 's/#bootstrap.memory_lock: true/bootstrap.system_call_filter: false/i' /opt/elasticsearch*/config/elasticsearch.yml
ADD start.sh /
CMD bash /start.sh
