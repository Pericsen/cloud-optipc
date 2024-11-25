
# import csv
# import os
# import subprocess
# import sys

# try:
#     import boto3
# except ImportError:
#     print("boto3 no encontrado, instalándolo...")
#     subprocess.check_call([sys.executable, "-m", "pip", "install", "boto3"])

# s3_client = boto3.client('s3')
# dynamodb_client = boto3.resource('dynamodb')
# table_name = "componentes"  # Nombre de la tabla actualizado

# def lambda_handler(event, context):
#     # Get bucket name and object key from the event
#     bucket_name = event['Records'][0]['s3']['bucket']['name']
#     object_key = event['Records'][0]['s3']['object']['key']

#     # Download the CSV file from S3
#     download_path = f'/tmp/{object_key.split("/")[-1]}'
#     s3_client.download_file(bucket_name, object_key, download_path)

#     # Read CSV and put items into DynamoDB
#     table = dynamodb_client.Table(table_name)

#     with open(download_path, 'r') as csvfile:
#         csv_reader = csv.DictReader(csvfile)
#         for row in csv_reader:
#             # Adjust the keys of row as per your DynamoDB table schema
#             dynamodb_item = {
#                 'partType': row['partType'],
#                 'name': row['name'],
#                 'image': row['image'],
#                 'url': row['url'],
#                 'sizeType': row['sizeType'],
#                 'storageType': row['storageType'],
#                 'brand': row['brand'],
#                 'socket': row['socket'],
#                 'speed': row['speed'],
#                 'coreCount': row['coreCount'],
#                 'threadCount': row['threadCount'],
#                 'power': row['power'],
#                 'VRAM': row['VRAM'],
#                 'resolution': row['resolution'],
#                 'size': row['size'],
#                 'space': row['space'],
#                 'productId': row['productId'],
#                 'precio_ficticio': row['precio_ficticio'],
#                 'price_category': row['price_category']
#             }
#             table.put_item(Item=dynamodb_item)

#     return {
#         'statusCode': 200,
#         'body': 'CSV data imported into DynamoDB successfully.'
#     }


import csv
import subprocess
import sys

try:
    import boto3
except ImportError:
    print("boto3 no encontrado, instalándolo...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "boto3"])

# Configurar el cliente DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = "componentes"
table = dynamodb.Table(table_name)

# Leer el archivo CSV
csv_file = "./data/componentes_optimizados.csv"

with open(csv_file, mode='r') as file:
    reader = csv.DictReader(file)
    for row in reader:
        # Adjust the keys of row as per your DynamoDB table schema
        dynamodb_item = {
            'partType': row['partType'],
            'name': row['name'],
            'image': row['image'],
            'url': row['url'],
            'sizeType': row['sizeType'],
            'storageType': row['storageType'],
            'brand': row['brand'],
            'socket': row['socket'],
            'speed': row['speed'],
            'coreCount': row['coreCount'],
            'threadCount': row['threadCount'],
            'power': row['power'],
            'VRAM': row['VRAM'],
            'resolution': row['resolution'],
            'size': row['size'],
            'space': row['space'],
            'productId': row['productId'],
            'precio_ficticio': row['precio_ficticio'],
            'price_category': row['price_category']
        }
        table.put_item(Item=dynamodb_item)

print(f"Importación de {csv_file} completada.")