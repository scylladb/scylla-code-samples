import boto3
dynamodb = boto3.resource('dynamodb',endpoint_url='http://172.17.0.2:8000',
                  region_name='None', aws_access_key_id='None', aws_secret_access_key='None')

dynamodb.batch_write_item(RequestItems={
    'mutant_data': [
        {
             'PutRequest': {
                 'Item': {
                     "last_name": "Loblaw",
                     "first_name": "Bob",
                     "address": "1313 Mockingbird Lane"
                 }
              }
        },
        {
             'PutRequest': {
                 'Item': {
                     "last_name": "Jeffries",
                     "first_name": "Jim",
                     "address": "1211 Hollywood Lane"
                 }
             }
        }
    ]
})

table = dynamodb.Table('mutant_data')
print("Finished writing to table ", table.table_name)

