FROM alpine
RUN apk update;apk add git alpine-sdk nodejs nodejs-npm python alpine-sdk
RUN git clone --depth 1 -b 6.1 https://github.com/elastic/kibana.git
RUN cd /kibana;npm install
RUN sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/i' /kibana/config/kibana.yml
RUN sed -i 's/#elasticsearch.url: "http:\/\/localhost:9200"/elasticsearch.url: "http:\/\/elasticsearch-master:9200"/i' /kibana*/config/kibana.yml
RUN sed -i 's/#server.port: 5601/server.port: 5601/i' /kibana/config/kibana.yml
RUN sed -i 's/#elasticsearch.requestTimeout: 30000/elasticsearch.requestTimeout: 120000/i' /kibana/config/kibana.yml
RUN sed -i 's/6.11.1/6.10.3/i' /kibana/.node-version
CMD cd /kibana;npm start
