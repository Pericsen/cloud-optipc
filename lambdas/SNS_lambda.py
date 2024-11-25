import boto3
import json
import os


sns_client = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']  # Usa el nombre de la variable configurada


def lambda_handler(event, context):
    for record in event['Records']:
        if record['eventName'] == 'INSERT':
            new_image = record['dynamodb']['NewImage']
            message = f"Nuevo componente cargado: {json.dumps(new_image)}"
            response = sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=message,
                Subject="Notificación de nuevo componente"
            )
    return {'statusCode': 200, 'body': 'Notification sent'}