FROM python:3.11

RUN mkdir -p /usr/src/app
COPY main.py /usr/src/app/
WORKDIR /usr/src/app

ENV PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["python", "main.py"]
