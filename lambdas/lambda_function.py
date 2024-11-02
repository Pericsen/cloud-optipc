import json
import boto3
import csv
import io
import os

# s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    csv_content = event['body']

    if isinstance(csv_content, str):
        csv_content = csv_content.encode('utf-8')

    # Leer el archivo CSV desde el contenido del body
    reader = csv.DictReader(io.StringIO(csv_content.decode('utf-8')))

    # Conectar a DynamoDB
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE_NAME'])

    # Insertar cada fila del CSV en la tabla DynamoDB
    for row in reader:
        table.put_item(
            Item={
                'partType': row['partType'],
                'name': row['name'],
                'image': row['image'],
                'url': row['url'],
                'sizeType': row['sizeType'],
                'storageType': row['storageType'],
                'brand': row['brand'],
                'socket': row['socket'],
                'speed': row['speed'],
                'coreCount': int(row['coreCount']),
                'threadCount': int(row['threadCount']),
                'power': int(row['power']),
                'VRAM': int(row['VRAM']),
                'resolution': row['resolution'],
                'size': int(row['size']),
                'space': int(row['space']),
                'productId': row['productId'],
                'precio': int(row['precio'])
            }
        )

    return {
        'statusCode': 200,
        'body': json.dumps('CSV loaded into DynamoDB successfully!')
    }