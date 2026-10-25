FROM python:3.12-alpine
RUN apk add --no-cache gcc musl-dev libev-dev
COPY requirements.txt /
RUN pip install -r /requirements.txt
COPY python-app/ /app
COPY python-app-ps/ /app
COPY python-datatypes/ /app
WORKDIR /app

ENTRYPOINT ["python3"]
CMD ["app.py"]
