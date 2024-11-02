import boto3
import pandas as pd
from decimal import Decimal

# Conectar con DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('optipc-csv-data-nic')  # Asegúrate de que el nombre de la tabla sea correcto


def obtener_componentes():
    # Obtener todos los componentes desde la tabla DynamoDB.
    response = table.scan()
    componentes = response['Items']
    df = pd.DataFrame(componentes)
    df['precio'] = df['precio'].astype(float)
    return df

def seleccionar_componentes(presupuesto, prioridades):
    # Obtener los datos de componentes
    df = obtener_componentes()
    
    # Filtrar por prioridades (si existen)
    if prioridades:
        for prioridad in prioridades:
            df_prioridad = df[df['partType'] == prioridad['tipo']]
            df_prioridad = df_prioridad.sort_values(by='precio', ascending=prioridad['preferencia'] == 'menor')
            # Elegir el componente de mayor o menor precio según la preferencia
            if not df_prioridad.empty:
                df = df.drop(df_prioridad.index[1:])
    
    # Agrupar los componentes por tipo y seleccionar el más barato que ajuste el presupuesto
    componentes_seleccionados = {}
    for part_type, group in df.groupby('partType'):
        group = group.sort_values(by='precio')
        for index, row in group.iterrows():
            if presupuesto - row['precio'] >= 0:
                presupuesto -= row['precio']
                componentes_seleccionados[part_type] = row
                break
    
    return componentes_seleccionados, presupuesto

# Ejemplo de uso:
# Supongamos que el usuario tiene un presupuesto de 1500 y prioridad por CPU de menor precio.
presupuesto_usuario = 1500
prioridades_usuario = [{'tipo': 'CPU', 'preferencia': 'menor'}]

componentes_optimizados, presupuesto_restante = seleccionar_componentes(presupuesto_usuario, prioridades_usuario)

print("Componentes seleccionados:")
for tipo, componente in componentes_optimizados.items():
    print(f"{tipo}: {componente['name']} - Precio: {componente['precio']}")

print(f"Presupuesto restante: {presupuesto_restante}")
