FROM node:22-alpine
COPY nodejs-app/ /app
WORKDIR /app
RUN npm install cassandra-driver
RUN npm install async

CMD ["node", "part1_app.js"]
