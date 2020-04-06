FROM python:3.7-alpine
COPY requirements.txt /
RUN pip install -r /requirements.txt
COPY python-app/ /app
COPY python-app-ps/ /app
COPY python-datatypes/ /app
WORKDIR /app

ENTRYPOINT ["python3"]
CMD ["app.py"]
