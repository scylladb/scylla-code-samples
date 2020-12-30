FROM alpine
RUN apk update;apk add shadow bash openjdk8 apache-ant wget unzip
WORKDIR /opt/code/libs
RUN wget -q https://repo1.maven.org/maven2/io/netty/netty-all/4.0.56.Final/netty-all-4.0.56.Final.jar
RUN wget -q http://downloads.datastax.com/java-driver/cassandra-java-driver-3.5.0.tar.gz;tar xf cassandra-java-driver-3.5.0.tar.gz
RUN mv cassandra-java-driver-3.5.0/*.jar .;mv cassandra-java-driver-3.5.0/lib/* .
WORKDIR /opt/code
COPY . /opt/code/
WORKDIR /opt/code/libs
RUN cp -r . /opt/code/java-app/libs/
WORKDIR /opt/code/java-app
RUN ant
WORKDIR /opt/code/libs
RUN cp -r . /opt/code/java-app-ps/libs/
WORKDIR /opt/code/java-app-ps
RUN ant
WORKDIR /opt/code/libs
RUN cp -r . /opt/code/java-datatypes/libs/
WORKDIR /opt/code/java-datatypes
RUN ant
WORKDIR /opt/code

CMD tail -f /dev/null
