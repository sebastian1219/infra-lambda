import boto3
import json

dynamo = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamo.Table('ImageMetadata')  # O usa os.environ['TABLE_NAME']

def lambda_handler(event, context):
    print(f"🔍 Evento recibido: {json.dumps(event)}")

    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"📦 Procesando: {bucket}/{key}")

        try:
            # Validar existencia y obtener metadatos
            metadata = s3.head_object(Bucket=bucket, Key=key)
            size = metadata['ContentLength']

            # Construir item para DynamoDB
            item = {
                'image_id': key,  # Puedes usar os.path.basename(key) si prefieres solo el nombre
                'bucket': bucket,
                'size': size
            }

            table.put_item(Item=item)
            print(f"✅ Guardado en DynamoDB: {item}")

        except Exception as e:
            print(f"❌ Error: {str(e)}")

    return {
        'statusCode': 200,
        'body': 'Proceso completado'
    }

