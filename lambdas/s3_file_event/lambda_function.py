import boto3
import os
import json

# Inicialización de clientes
dynamo = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamo.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    print("🔔 Evento recibido:")
    print(json.dumps(event, indent=2))

    records = event.get('Records', [])
    if not records:
        print("⚠️ No se encontraron registros en el evento.")
        return response(400, "Sin registros para procesar")

    for record in records:
        try:
            event_name = record.get('eventName', '')
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            print(f"📦 Evento: {event_name} → {bucket}/{key}")

            if event_name.startswith("ObjectCreated"):
                metadata = s3.head_object(Bucket=bucket, Key=key)
                size = metadata.get('ContentLength', 0)

                item = {
                    'image_id': key,
                    'bucket': bucket,
                    'size': size
                }

                table.put_item(Item=item)
                print(f"✅ Guardado en DynamoDB: {item}")

            elif event_name.startswith("ObjectRemoved"):
                table.delete_item(Key={'image_id': key})
                print(f"🗑️ Eliminado de DynamoDB: {key}")

            else:
                print(f"⚠️ Evento no manejado: {event_name}")

        except Exception as e:
            print(f"❌ Error procesando {key}: {str(e)}")

    return response(200, "Evento procesado correctamente")

def response(status, message):
    return {
        'statusCode': status,
        'body': json.dumps({'message': message})
    }

