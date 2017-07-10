FROM ubuntu
RUN apt-get update;apt-get install -y git curl build-essential python
RUN curl -sL https://deb.nodesource.com/setup_8.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install -y nodejs
ADD * /twitter/
WORKDIR /twitter
RUN npm install;npm install express system-sleep
CMD node --optimize_for_size --max_old_space_size=460 --gc_interval=100 main.js
