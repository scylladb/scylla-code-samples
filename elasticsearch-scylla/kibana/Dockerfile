FROM ubuntu
RUN apt-get update;apt-get install -y git curl build-essential python
RUN curl -sL https://deb.nodesource.com/setup_6.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install -y nodejs
RUN git clone https://github.com/elastic/kibana.git
RUN cd /kibana;npm install
RUN sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/i' /kibana*/config/kibana.yml
RUN sed -i 's/#elasticsearch.url: "http:\/\/localhost:9200"/elasticsearch.url: "http:\/\/elasticsearch-master:9200"/i' /kibana*/config/kibana.yml
CMD cd /kibana;npm start
