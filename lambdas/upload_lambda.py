import json
import boto3
import csv
import io
import os

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Access-Control-Allow-Credentials': 'true'
    }
    try:
        body = event.get('body', '')

        if isinstance(body, str):
            # Decodificar el JSON si es necesario
            try:
                body = json.loads(body)
            except json.JSONDecodeError:
                pass  # Si no es JSON, usar el string tal cual

        csv_content = body.replace('\\n', '\n').strip('"')
        print("csv recibido: " + csv_content)

        # Leer el archivo CSV desde el contenido del body
        reader = csv.DictReader(io.StringIO(csv_content))

        # Conectar a DynamoDB
        table = dynamodb.Table('componentes')

        # Insertar cada fila del CSV en la tabla DynamoDB
        for row in reader:
            print("Fila procesada:", json.dumps(row, indent=2))
            numeric_columns = ['coreCount', 'threadCount', 'power', 'VRAM', 'size', 'space', 'precio_ficticio']

            item={
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

            print("Item a insertar:", json.dumps(item, indent=2))

            table.put_item(Item=item)

        return {
            'statusCode': 200,
            'body': json.dumps('CSV loaded into DynamoDB successfully!'),
            'headers': headers
        }
        
    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps(f'Error en el formato de la solicitud: {str(e)}'),
            'headers': headers
        }
    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps(f'Error en el formato de los datos: {str(e)}'),
            'headers': headers
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error interno del servidor: {str(e)}'),
            'headers': headers
        }
