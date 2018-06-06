FROM alpine
RUN apk update;apk add nodejs nodejs-npm
COPY * /webconsole/
WORKDIR /webconsole
CMD npm install;node --expose-gc --max_old_space_size=5024 main.js
