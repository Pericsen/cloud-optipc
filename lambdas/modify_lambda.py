import boto3
import json
from boto3.dynamodb.conditions import Key
import os

# Inicializar el cliente de DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('componentes')

def lambda_handler(event, context):
    try:
        print("Evento recibido:", event)

        # Verificar si 'body' existe en el evento
        if 'body' not in event:
            raise ValueError("El evento no contiene 'body'.")

        # Obtener datos del frontend
        data = json.loads(event['body'])
        tipo_componente = data.get('tipo_componente')
        precio_ficticio = data.get('precio_ficticio')

        if tipo_componente is None or precio_ficticio is None:
            raise ValueError("Faltan parámetros 'tipo_componente' o 'precio_ficticio'.")

        # Convertir 'tipo_componente' a minúsculas para consistencia
        tipo_componente = tipo_componente.lower()

        # Asegurarse de que 'precio_ficticio' sea un string
        precio_ficticio = int(float(precio_ficticio))

        # Calcular el rango de precios (como string)
        rango_min = str(precio_ficticio * 0.9)
        rango_max = str(precio_ficticio * 1.1)

        # Realizar un query usando el GSI
        response = table.query(
            IndexName='precio-index',  # Nombre del GSI que creaste
            KeyConditionExpression=Key('partType').eq(tipo_componente) & Key('precio_ficticio').between(rango_min, rango_max)
        )

        # Obtener los elementos del resultado de la consulta
        items = response.get('Items', [])

        # Ordenar los resultados por 'precio_ficticio' de mayor a menor
        items.sort(key=lambda x: float(x['precio_ficticio']), reverse=True)

        # Seleccionar hasta un máximo de 5 opciones
        resultado = items[:5]

        print("Opciones encontradas:", resultado)

        # Devolver el resultado
        return {
            'statusCode': 200,
            'body': json.dumps({'alternatives': resultado}, default=str),
            'headers': {
                'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            }
        }
    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {
                'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            }
        }
