FROM hseeberger/scala-sbt:graalvm-ce-20.0.0-java11_1.3.13_2.13.3

WORKDIR /mms/scala-app
ADD scala-app .
RUN sbt assembly

WORKDIR /mms

CMD tail -f /dev/null
