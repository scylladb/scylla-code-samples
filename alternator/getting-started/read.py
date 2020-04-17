from __future__ import print_function
import boto3
dynamodb = boto3.resource('dynamodb',endpoint_url='http://172.17.0.2:8000',
                  region_name='None', aws_access_key_id='None', aws_secret_access_key='None')

response = dynamodb.batch_get_item(
    RequestItems={
        'mutant_data' : { 'Keys': [{ 'last_name': 'Loblaw' }, {'last_name': 'Jeffries'}] }
    }
)
for x in response:
    print (x)
    for y in response[x]:
        print (y,':',response[x][y])

