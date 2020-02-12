FROM python:3.7-alpine
COPY requirements.txt /
RUN pip install -r /requirements.txt
COPY python-app/ /app
COPY python-app-ps/ /app
WORKDIR /app

ENTRYPOINT ["python"]
CMD ["app.py"]
