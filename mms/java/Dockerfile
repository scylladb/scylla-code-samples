FROM alpine
RUN apk update;apk add shadow bash openjdk8 maven
WORKDIR /opt/code
COPY . /opt/code/
WORKDIR /opt/code/java-app
RUN mvn package
WORKDIR /opt/code/java-app-ps
RUN mvn package
WORKDIR /opt/code/java-datatypes
RUN mvn package
WORKDIR /opt/code

CMD tail -f /dev/null
