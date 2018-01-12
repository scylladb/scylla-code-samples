FROM alpine
WORKDIR /opt
RUN apk update;apk add shadow py-pip less bash openjdk8-jre-base tar wget
RUN wget -q -O zeppelin.tar.gz http://apache.claz.org/zeppelin/zeppelin-0.7.3/zeppelin-0.7.3-bin-all.tgz
RUN tar xf zeppelin.tar.gz
ADD interpreter.json /opt/zeppelin-0.7.3-bin-all/conf/
CMD ./zepp*/bin/zeppelin-daemon.sh start;tail -f /dev/null
