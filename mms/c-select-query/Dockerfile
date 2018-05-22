FROM alpine
RUN apk update;apk add build-base git cmake openssl-dev libuv-dev
COPY app.cpp /opt/code/
WORKDIR /opt
RUN git clone --depth=1 https://github.com/datastax/cpp-driver.git
WORKDIR /opt/cpp-driver
RUN cmake .;make -j8 install
WORKDIR /opt/code/
RUN g++ app.cpp -Lbuild -lcassandra -Iinclude
RUN chmod +x a.out
CMD ./a.out