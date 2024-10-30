import boto3
import csv

def migrate_data_to_dynamodb(file_path, dynamodb_table_name):
    # Inicializar el cliente de DynamoDB
    dynamodb_client = boto3.client('dynamodb')

    # Leer el archivo CSV
    with open(file_path, 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        column_names = reader.fieldnames  

        # Enviar datos a DynamoDB
        for row in reader:
            item = {
                'partType': {'S': row['partType']},
                'name': {'S': row['name']},
                'image': {'S': row['image']},
                'url': {'S': row['url']},
                'sizeType': {'S': row['sizeType']},
                'storageType': {'S': row['storageType']},
                'brand': {'S': row['brand']},
                'socket': {'S': row['socket']},
                'speed': {'S': row['speed']},
                'coreCount': {'N': str(row['coreCount'])},  # Aseguramos que sea tipo String para números
                'threadCount': {'N': str(row['threadCount'])},
                'power': {'N': str(row['power'])},
                'VRAM': {'N': str(row['VRAM'])},
                'resolution': {'S': row['resolution']},
                'size': {'N': str(row['size'])},
                'space': {'N': str(row['space'])},
                'productId': {'S': str(row['productId'])},  # Aseguramos que sea String
                'precio': {'N': str(row['precio'])}
            }

            # Cargar el ítem en la tabla DynamoDB
            dynamodb_client.put_item(TableName=dynamodb_table_name, Item=item)

        print(f"Datos de {file_path} se han subido exitosamente a la tabla DynamoDB {dynamodb_table_name}.")

# Ejemplo de uso
local_csv_file_path = 'C:/CLOUD/cloud-optipc/modules/csv-to-ddb/componentes_final.csv'
dynamodb_table_name = 'componentes-nic'  # Cambié el nombre de la tabla a 'componentes'

migrate_data_to_dynamodb(local_csv_file_path, dynamodb_table_name)
