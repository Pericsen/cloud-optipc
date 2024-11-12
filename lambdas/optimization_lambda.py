import boto3
import json
import pandas as pd
import os

# Inicializar el cliente de DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('componentes')

def lambda_handler(event, context):
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': 'http://' + os.environ.get('BUCKET_NAME') + '.s3-website-us-east-1.amazonaws.com',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'OPTIONS,GET'
    }
    
    try:
        print("Evento recibido:", event)

        if 'body' not in event:
            raise ValueError("El evento no contiene 'body'.")

        # Obtener datos del frontend
        query_parameters = event.get('queryStringParameters', {})
        if not query_parameters:
            raise ValueError("No se proporcionaron parámetros de consulta.")
        
        presupuesto = query_parameters.get('presupuesto')
        tipo_uso = query_parameters.get('tipo_uso')

        if presupuesto is None or tipo_uso is None:
            raise ValueError("Faltan parámetros 'presupuesto' o 'tipo_uso'.")

        # Asegurar que 'presupuesto' es un número
        try:
            presupuesto = float(presupuesto)
        except (ValueError, TypeError):
            raise ValueError("El parámetro 'presupuesto' debe ser un número.")


        # Usar scan para obtener todos los elementos de la tabla
        response = table.scan()
        db_data = response.get('Items', [])

        # Si hay paginación, continuar obteniendo los siguientes elementos
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            db_data.extend(response.get('Items', []))

        # Convertir los datos de DynamoDB en un DataFrame de pandas
        df = pd.DataFrame(db_data)

        # Convertir las columnas relevantes a tipo numérico
        if 'precio' in df.columns:
            df['precio'] = pd.to_numeric(df['precio'], errors='coerce')

        # Lógica de optimización usando pandas
        result = seleccionar_componentes(df, presupuesto, tipo_uso)

        # Asegurarse de que result es una lista
        if not isinstance(result, list):
            result = []

        print("Resultado de componentes seleccionados:", result)  # Log del resultado

        # Devolver el resultado
        return {
            'statusCode': 200,
            'body': json.dumps({'components': result}),
            'headers': headers
        }
    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)}),
            'headers': headers
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
            opciones['diferencia'] = abs(opciones['precio'] - presupuesto_asignado)
            mejor_opcion = opciones.sort_values(by='diferencia').iloc[0]
            seleccion.append({
                'partType': mejor_opcion['partType'],
                'name': mejor_opcion['name'],
                'url': mejor_opcion['url'],
                'precio': mejor_opcion['precio']
            })

    return seleccion