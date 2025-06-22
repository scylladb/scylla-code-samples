FROM eclipse-temurin:21-alpine

# Install dependencies
RUN apk update && apk add --no-cache \
    shadow \
    bash \
    maven

# Set working directory
WORKDIR /opt/code

# Copy project files
COPY . /opt/code/

# Build Java applications
WORKDIR /opt/code/java-app
RUN mvn clean package

WORKDIR /opt/code/java-app-ps  
RUN mvn clean package

WORKDIR /opt/code/java-datatypes
RUN mvn clean package

WORKDIR /opt/code

CMD tail -f /dev/null
