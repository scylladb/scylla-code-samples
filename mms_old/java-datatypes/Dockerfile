FROM alpine
RUN apk update;apk add shadow bash openjdk8 apache-ant wget unzip
WORKDIR /opt/code/libs
RUN wget -q https://oss.sonatype.org/content/repositories/snapshots/io/netty/netty-all/4.0.56.Final-SNAPSHOT/netty-all-4.0.56.Final-20180202.121251-12.jar
RUN wget -q http://downloads.datastax.com/java-driver/cassandra-java-driver-3.5.0.tar.gz;tar xf cassandra-java-driver-3.5.0.tar.gz
RUN mv cassandra-java-driver-3.5.0/*.jar .;mv cassandra-java-driver-3.5.0/lib/* .
WORKDIR /opt/code
COPY . /opt/code/
ADD build.xml /opt/code/
RUN ant
WORKDIR /opt/code/dist
CMD tail -f /dev/null
