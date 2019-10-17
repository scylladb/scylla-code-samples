FROM alpine
RUN apk update;apk add nodejs nodejs-npm
COPY * /loadgen/
WORKDIR /loadgen
CMD npm install;node --expose-gc --max_old_space_size=5024 main.js
