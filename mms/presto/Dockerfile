FROM alpine
WORKDIR /opt
RUN apk update;apk add shadow py-pip less bash openjdk8-jre-base tar wget
RUN wget -q -O presto.tar.gz https://repo1.maven.org/maven2/com/facebook/presto/presto-server/0.190/presto-server-0.190.tar.gz
RUN tar xvf presto.tar.gz
ADD resources /opt/presto-server-0.190/
RUN echo "node.environment=production" > /opt/presto-server-0.190/etc/node.properties
RUN echo "node.id=ffffffff-ffff-ffff-ffff-ffffffffffff" >> /opt/presto-server-0.190/etc/node.properties
RUN echo "node.data-dir=/opt/presto-server-0.190/data" >> /opt/presto-server-0.190/etc/node.properties
RUN mkdir /opt/presto-server-0.190/data
WORKDIR /opt/presto-server-0.190/bin
RUN wget -q -O presto-cli.jar https://repo1.maven.org/maven2/com/facebook/presto/presto-cli/0.190/presto-cli-0.190-executable.jar
RUN chmod +x presto-cli.jar
CMD ./launcher run;tail -f /dev/null
