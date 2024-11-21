import boto3
import json
import pandas as pd
import os
from datetime import datetime
# import jwt

# Inicializar el cliente de DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('componentes')

def lambda_handler(event, context):
    try:
        print("Evento recibido:", event)  # Log del evento recibido
        
        # auth_header = event.get('headers', {}).get('Authorization')
        # user_id = None
        # username = None
        
        # if auth_header and auth_header.startswith('Bearer '):
        #     token = auth_header.split(' ')[1]
        #     try:
        #         # Decodificar el token JWT
        #         decoded_token = jwt.decode(token, verify=False)  # Ajusta según tu configuración de JWT
        #         user_id = decoded_token.get('sub')
        #         username = decoded_token.get('username')
        #     except Exception as e:
        #         print("Error decodificando token:", str(e))

        # Verificar si 'body' existe en el evento
        if 'body' not in event:
            raise ValueError("El evento no contiene 'body'.")

        # Obtener datos del frontend
        data = json.loads(event['body'])
        presupuesto = data.get('presupuesto')
        tipo_uso = data.get('tipo_uso')

        if presupuesto is None or tipo_uso is None:
            raise ValueError("Faltan parámetros 'presupuesto' o 'tipo_uso'.")

        # Asegurar que 'presupuesto' es un número
        try:
            presupuesto = float(presupuesto)
        except (ValueError, TypeError):
            raise ValueError("El parámetro 'presupuesto' debe ser un número.")


        # Usar scan para obtener todos los elementos de la tabla
        tableComponentes = dynamodb.Table('componentes')
        response = tableComponentes.scan()
        db_data = response.get('Items', [])

        # Si hay paginación, continuar obteniendo los siguientes elementos
        while 'LastEvaluatedKey' in response:
            response = tableComponentes.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            db_data.extend(response.get('Items', []))

        # Convertir los datos de DynamoDB en un DataFrame de pandas
        df = pd.DataFrame(db_data)

        # Convertir las columnas relevantes a tipo numérico
        if 'precio_ficticio' in df.columns:
            df['precio_ficticio'] = pd.to_numeric(df['precio_ficticio'], errors='coerce')

        # Lógica de optimización usando pandas
        result = seleccionar_componentes(df, presupuesto, tipo_uso)
        
        # Guardar la optimización en DynamoDB si el usuario está autenticado
        # if user_id and username:
        #     tablaOptimizaciones = dynamodb.Table('optimizaciones')
            
        #     optimizacion = {
        #         'userId': user_id,
        #         'username': username,
        #         'datetime': datetime.now().isoformat(),
        #         'presupuesto': presupuesto,
        #         'tipo_uso': tipo_uso,
        #         'componentes': result
        #     }
            
        #     tablaOptimizaciones.put_item(Item=optimizacion)
        #     print("Optimización guardada para el usuario:", username)

        # Asegurarse de que result es una lista
        if not isinstance(result, list):
            result = []

        print("Resultado de componentes seleccionados:", result)  # Log del resultado

        # Devolver el resultado
        return {
            'statusCode': 200,
            'body': json.dumps({'components': result}),
            'headers': {
                'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',  # Asegura que CORS está incluido
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            }
        }
    except Exception as e:
        print("Error:", str(e))  # Log del error
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {
                'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',  # Asegura que CORS está incluido en errores
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            }
        }

# Funciones auxiliares
def obtener_categoria_presupuesto(presupuesto):
    if presupuesto < 800:
        return "barato"
    elif 800 <= presupuesto < 1100:
        return "intermedio"
    elif 1100 <= presupuesto < 1500:
        return "caro"
    else:
        return "muy caro"

def obtener_distribucion_presupuesto(presupuesto, tipo_uso):
    distribuciones = {
        'Gaming': {
            'gpu': 0.3 * presupuesto,
            'cpu': 0.2 * presupuesto,
            'motherboard': 0.2 * presupuesto,
            'psu': 0.1 * presupuesto,
            'storage': 0.1 * presupuesto,
            'memory': 0.1 * presupuesto
        },
        'Trabajo': {
            'gpu': 0.1 * presupuesto,
            'cpu': 0.3 * presupuesto,
            'motherboard': 0.1 * presupuesto,
            'psu': 0.1 * presupuesto,
            'storage': 0.2 * presupuesto,
            'memory': 0.2 * presupuesto
        },
        'Balanceado': {
            'gpu': 0.2 * presupuesto,
            'cpu': 0.2 * presupuesto,
            'motherboard': 0.2 * presupuesto,
            'psu': 0.1 * presupuesto,
            'storage': 0.2 * presupuesto,
            'memory': 0.1 * presupuesto
        }
    }
    if tipo_uso not in distribuciones:
        raise ValueError("Tipo de uso no válido. Debe ser 'Gaming', 'Trabajo', o 'Balanceado'.")
    return distribuciones[tipo_uso]

def seleccionar_componentes(df, presupuesto, tipo_uso):
    # Determinar la categoría de precio en función del presupuesto
    categoria_presupuesto = obtener_categoria_presupuesto(presupuesto)

    # Obtener la distribución del presupuesto según el tipo de uso
    distribucion_presupuesto = obtener_distribucion_presupuesto(presupuesto, tipo_uso)

    # Crear una lista para almacenar los componentes seleccionados
    seleccion = []

    # Iterar sobre cada tipo de componente y su presupuesto asignado
    for componente, presupuesto_asignado in distribucion_presupuesto.items():
        # Filtrar el DataFrame por el tipo de componente y la categoría de precio
        opciones = df[
            (df['partType'].str.lower() == componente.lower()) & 
            (df['price_category'].str.lower() == categoria_presupuesto.lower())
        ].copy()

        # Si no hay opciones dentro de la categoría de precio, relajar la restricción de categoría
        if opciones.empty:
            opciones = df[df['partType'].str.lower() == componente.lower()].copy()

        # Seleccionar el componente con el precio más cercano al presupuesto asignado
        if not opciones.empty:
            opciones['diferencia'] = abs(opciones['precio_ficticio'] - presupuesto_asignado)
            mejor_opcion = opciones.sort_values(by='diferencia').iloc[0]
            seleccion.append({
                'partType': mejor_opcion['partType'],
                'name': mejor_opcion['name'],
                'url': mejor_opcion['url'],
                'precio': mejor_opcion['precio_ficticio']
            })

    return seleccion
