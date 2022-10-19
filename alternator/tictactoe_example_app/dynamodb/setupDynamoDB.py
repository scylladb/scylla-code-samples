# Copyright 2014. Amazon Web Services, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import boto3, logging, time

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen
import json

import boto3_alternator

def getDynamoDBConnection(config=None, endpoint=None, port=None, local=False, use_instance_metadata=False):
    # Explode endpoint into a list if a comma-separated value was provided
    # Otherwise just build a list with the single endpoint in it
    if ',' in endpoint:
        endpoint = endpoint.split(',')
    else:
        endpoint = [endpoint]
    # Set up load balancing for Alternator
    endpoint = boto3_alternator.setup2(
    # A list of known Alternator nodes. One of them must be responsive.
    endpoint,
    # Alternator scheme (http or https) and port
    'http', 8000,
    # A "fake" domain name which, if used by the application, will be
    # resolved to one of the Scylla nodes.
    'tic-tac-toe.scylla.example')

    if local:
        db = boto3.resource('dynamodb',
            endpoint_url=endpoint,
            aws_secret_access_key='ticTacToeSampleApp',
            aws_access_key_id='ticTacToeSampleApp',
            region_name="local")
    else:
        params = {
            
            }

        # Read from config file, if provided
        if config is not None:
            if config.has_option('dynamodb', 'region'):
                params['region'] = config.get('dynamodb', 'region')
            if config.has_option('dynamodb', 'endpoint'):
                params['host'] = config.get('dynamodb', 'endpoint')

            if config.has_option('dynamodb', 'aws_access_key_id'):
                params['aws_access_key_id'] = config.get('dynamodb', 'aws_access_key_id')
                params['aws_secret_access_key'] = config.get('dynamodb', 'aws_secret_access_key')

        # Use the endpoint specified on the command-line to trump the config file
        if endpoint is not None:
            params['host'] = endpoint
            if 'region' in params:
                del params['region']

        # Only auto-detect the DynamoDB endpoint if the endpoint was not specified through other config
        if 'host' not in params and use_instance_metadata:
            response = urlopen('http://169.254.169.254/latest/dynamic/instance-identity/document').read()
            doc = json.loads(response);
            params['host'] = 'dynamodb.%s.amazonaws.com' % (doc['region'])
            if 'region' in params:
                del params['region']

        db = boto3.resource('dynamodb', **params)
    return db

def createGamesTable(db):
    try:
        gamesTable = db.create_table(TableName="Games",
                    KeySchema=[{'AttributeName': "GameId",
                                'KeyType': 'HASH'}],
                    AttributeDefinitions=[
                    {
                        'AttributeName': 'GameId',
                        'AttributeType': 'S'
                    },
                    {
                        'AttributeName': 'HostId',
                        'AttributeType': 'S'
                    },
                    {
                        'AttributeName': 'StatusDate',
                        'AttributeType': 'S'
                    },
                    {
                        'AttributeName': 'OpponentId',
                        'AttributeType': 'S'
                    },
                    ],
                    ProvisionedThroughput={
                        'ReadCapacityUnits': 1,
                        'WriteCapacityUnits': 1
                    },
                    GlobalSecondaryIndexes=[
                    {
                        'IndexName': 'HostId-StatusDate-index',
                        'KeySchema': [
                            {
                                'AttributeName': 'HostId',
                                'KeyType': 'HASH'
                            },
                            {
                                'AttributeName': 'StatusDate',
                                'KeyType': 'RANGE'
                            },
                        ],
                        'Projection': {'ProjectionType': 'ALL',
                                       'NonKeyAttributes': [
                                            'string',
                        ]},
                        'ProvisionedThroughput': {
                            'ReadCapacityUnits': 123,
                            'WriteCapacityUnits': 123
                        }
                    },
                    {
                        'IndexName': 'OpponentId-StatusDate-index',
                        'KeySchema': [
                            {
                                'AttributeName': 'OpponentId',
                                'KeyType': 'HASH'
                            },
                            {
                                'AttributeName': 'StatusDate',
                                'KeyType': 'RANGE'
                            }
                        ],
                        'Projection': {'ProjectionType': 'ALL',
                                       'NonKeyAttributes': [
                                            'string',
                        ]},
                        'ProvisionedThroughput': {
                            'ReadCapacityUnits': 123,
                            'WriteCapacityUnits': 123
                        }
                        }
                    ]
                )
        time.sleep(5)
    except Exception as e:
        print('Create failed.')
        print(e)
        try:
            gamesTable = db.Table("Games")
        except Exception as e:
            print("Games Table doesn't exist.")
    finally:
        return gamesTable

#parse command line args for credentials and such
#for now just assume local is when args are empty
