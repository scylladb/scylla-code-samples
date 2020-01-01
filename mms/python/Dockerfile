FROM python:3.7-alpine
COPY python-app/requirements.txt /
RUN pip install -r /requirements.txt
COPY python-app/ /app
WORKDIR /app

CMD ["python", "./app.py"]
