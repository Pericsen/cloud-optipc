import json
import requests
import os
import boto3
from datetime import datetime, timezone

def lambda_handler(event, context):
    try:
        # Extraer los datos desde el evento
        body = event.get('data', {})
        budget = body.get('budget')
        components = body.get('components')
        
        # Verificar que budget y components no sean None
        if budget is None or components is None:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Faltan parámetros en la solicitud'})
            }
        
        # La IP privada de la EC2 donde se ejecuta el modelo de optimización
        ec2_endpoint = os.environ['EC2_ENDPOINT']
        headers = {'Content-Type': 'application/json'}
        
        dynamodb = boto3.resource('dynamodb')
        components_table = dynamodb.Table('componentes')
        
        # Escaneo de DynamoDB para obtener los componentes
        response = components_table.scan()
        components_data = response.get('Items', [])
        
        # Enviar los datos a la EC2
        payload = {
            'budget': budget,
            'priority-components': components,
            'components-data': components_data
        }
        
        ec2_response = requests.post(ec2_endpoint, json=payload, headers=headers)
        
        if ec2_response.status_code == 200:
            optimized_data = ec2_response.json()
            
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
                'statusCode': ec2_response.status_code,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'message': 'Error al procesar en la EC2', 'details': ec2_response.text})
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
