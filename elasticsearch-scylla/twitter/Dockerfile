FROM alpine
RUN apk update;apk add nodejs nodejs-npm
COPY * /twitter/
WORKDIR /twitter
CMD npm install;node main.js
