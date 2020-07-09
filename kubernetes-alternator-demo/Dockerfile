FROM alpine:latest as builder

RUN apk --no-cache add ca-certificates
RUN apk --no-cache add curl
RUN curl -L --output dynamodb-tictactoe-example-app.zip https://github.com/amazon-archives/dynamodb-tictactoe-example-app/archive/master.zip
RUN unzip dynamodb-tictactoe-example-app.zip 


FROM python:2.7-alpine3.11

RUN pip install Flask boto ConfigParser
RUN python --version
COPY --from=builder dynamodb-tictactoe-example-app-master dynamodb-tictactoe

WORKDIR dynamodb-tictactoe

CMD ["python", "application.py"]