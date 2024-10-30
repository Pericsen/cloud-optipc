import boto3
import csv
import os

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
def lambda_handler(event, context):
    table_name = os.environ['DYNAMODB_TABLE']
    bucket = os.environ['S3_BUCKET']
    key = os.environ['S3_KEY']
    
    table = dynamodb.Table(table_name)
    
    # Descargar el archivo CSV desde S3
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        rows = csv.DictReader(response['Body'].read().decode('utf-8').splitlines())
        
        # Subir cada fila a DynamoDB
        for row in rows:
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
        return {"statusCode": 200, "body": "Datos cargados exitosamente en DynamoDB"}

    except Exception as e:
        print(f"Error al cargar datos: {e}")
        return {"statusCode": 500, "body": "Error al cargar los datos"}
