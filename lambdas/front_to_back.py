import json
import requests
import os
import boto3
from datetime import datetime, timezone

def lambda_handler(event, context):
    try:
        # Extraer los datos desde el evento
        body = json.loads(event['body'])
        budget = body['budget']
        components = body['components']
        
        # La IP privada de la EC2 donde se ejecuta el modelo de optimización
        ec2_private_ip = os.environ['EC2_ENDPOINT']
        headers = {'Content-Type': 'application/json'}
        
        dynamodb = boto3.resource('dynamodb')
        components_table = dynamodb.Table('componentes')
        
        response = components_table.scan()
        if 'Items' in response:
            components_data = response['Items']
        else:
            components_data = []
        
        # Enviar los datos a la EC2
        payload = {
            'budget': budget,
            'priority-components': components,
            'components-data': components_data
        }
        
        response = requests.post(ec2_private_ip, json=payload, headers=headers)
        
        if response.status_code == 200:
            optimized_data = response.json()
            
            query_datetime = datetime.now(timezone.utc).isoformat()
            
            # Guardar resultado en DynamoDB
            optimizations_table = dynamodb.Table('optimizaciones')
            
            optimizations_table.put_item(Item={
                'userId': 1,
                'datetime': query_datetime,
                'budget': budget,
                'priority-components': components,
                'optimized_components': optimized_data,
            })
            
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({
                    'message': 'Optimización exitosa',
                    'optimized_components': optimized_data
                })
            }
        else:
            return {
                'statusCode': response.status_code,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'message': 'Error al procesar en la EC2'})
            }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'message': 'Error en la Lambda', 'error': str(e)})
        }
