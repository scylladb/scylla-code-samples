# Tic Tac Toe on DynamoDB

TicTacToe is a lightweight application that runs on Python and depends on two packages, Flask(2.2) and Boto3(1.21). You'll also need the boto3_alternator file from https://github.com/scylladb/alternator-load-balancing/blob/master/python/boto3_alternator.py.  If you want in depth information about the application and DynamoDB check out [Tic Tac Toe on DynamoDB](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ExampleApps.html).

Below are instructions that will help you launch the application.
These instructions will also require you to have access to a terminal.

**Note: May need administrative privileges for these installations**

## Installing Python

If you don't have Python installed by default, download Python (use v3.6+) by following the instructions on https://www.python.org/download/

## Installing required dependencies:
    
Download/install pip *(Follow the instructions here http://pip.readthedocs.org/en/latest/installing.html)*

   Once you have pip up to date and installed, clone this repo, cd to its dir and run:.

        pip3 install -r /path/to/requirements.txt

## Configuring Tic Tac Toe
Once you have these dependencies set up, you will have to run the application with your own configurations.

The full list of options is as follows:

      python3 application.py [-h] [--config pathToConfig] [--mode (local | service)]
                            [--endpoint ENDPOINT] [--port dbPort] [--serverPort flaskPort]

Example:

      python3 application.py --mode local --endpoint $yourAlternatorIP

## Run Alternator

You can easily get an Alternator instance started by running the following:

      docker run --name scylladb-alternator scylladb/scylla:latest --smp 1 --memory 512M --alternator-port 8000 --alternator-write-isolation always
      sleep 1m
      yourAlternatorIP="$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' scylladb-alternator)"
      # then you can run the application.py passing variable $yourAlternatorIP
