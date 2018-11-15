FROM alpine
WORKDIR /opt
ARG version=0.8.0
RUN apk update;apk add shadow py-pip less bash openjdk8-jre-base tar wget
RUN wget -q -O zeppelin.tar.gz http://apache.claz.org/zeppelin/zeppelin-${version}/zeppelin-${version}-bin-all.tgz
RUN tar xf zeppelin.tar.gz
ADD interpreter.json /opt/zeppelin-${version}-bin-all/conf/
CMD ./zepp*/bin/zeppelin-daemon.sh start;tail -f /dev/null
