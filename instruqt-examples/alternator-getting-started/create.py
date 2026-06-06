from __future__ import print_function
import boto3
dynamodb = boto3.resource('dynamodb',endpoint_url='http://172.17.0.2:8000',
                  region_name='None', aws_access_key_id='None', aws_secret_access_key='None')

table = dynamodb.create_table(
    BillingMode='PAY_PER_REQUEST',
    TableName='mutant_data',
    KeySchema=[
    {
        'AttributeName': 'last_name',
        'KeyType': 'HASH'
    },
    ],
    AttributeDefinitions=[
    {
        'AttributeName': 'last_name',
        'AttributeType': 'S'
    },
    ]
)

print("Finished creating table ", table.table_name ,". Status: ", table.table_status)


