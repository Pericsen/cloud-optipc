import boto3
import json
from boto3.dynamodb.conditions import Key
import os

# Inicializar el cliente de DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
tableComponentes = dynamodb.Table('componentes')

def lambda_handler(event, context):
    headers = {
        'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
    }
    try:
        print("Evento recibido:", event)

        # Verificar si 'body' existe en el evento
        if 'body' not in event:
            raise ValueError("El evento no contiene 'body'.")

        # Obtener datos del frontend
        data = json.loads(event['body'])
        tipo_componente = data.get('tipo_componente')
        precio = data.get('precio')

        if tipo_componente is None or precio is None:
            raise ValueError("Faltan parámetros 'tipo_componente' o 'precio'.")

        # Convertir 'tipo_componente' a minúsculas para consistencia
        tipo_componente = tipo_componente.lower()

        # Asegurarse de que 'precio_ficticio' sea un string
        precio = str(precio)

        # Calcular el rango de precios (como string)
        rango_min = str(float(precio) * 0.9)
        rango_max = str(float(precio) * 1.1)

        # Realizar un query usando el GSI
        response = tableComponentes.query(
            IndexName='precio-indice',  # Nombre del GSI que creaste
            KeyConditionExpression=Key('partType').eq(tipo_componente) & Key('precio').between(rango_min, rango_max)
        )

        # Obtener los elementos del resultado de la consulta
        items = response.get('Items', [])
        
        # Ordenar los resultados por 'precio_ficticio' de mayor a menor
        items.sort(key=lambda x: float(x['precio']), reverse=True)

        # Seleccionar hasta un máximo de 5 opciones
        resultado = items[:5]

        print("Opciones encontradas:", resultado)

        # Devolver el resultado
        return {
            'statusCode': 200,
            'body': json.dumps({'alternatives': resultado}, default=str),
            'headers': headers
        }
    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': headers
        }