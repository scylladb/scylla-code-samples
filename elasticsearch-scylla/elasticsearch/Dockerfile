FROM alpine
WORKDIR /opt
RUN apk update;apk add shadow bash openjdk8-jre-base tar wget
RUN wget -q -O eleastic-search.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.1.0.tar.gz
RUN tar xf eleastic-search.tar.gz -C /opt/
RUN useradd -s /bin/bash elasticsearch -d /home/elasticsearch -m
RUN chown -R elasticsearch:elasticsearch /opt/elasticsearch*
RUN sed -i 's/#bootstrap.memory_lock: true/bootstrap.system_call_filter: false/i' /opt/elasticsearch*/config/elasticsearch.yml
ADD start.sh /
CMD bash /start.sh
