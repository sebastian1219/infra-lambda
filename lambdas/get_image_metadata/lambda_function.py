import boto3
import os
import json
import urllib.parse

dynamo = boto3.resource('dynamodb')
table = dynamo.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    method = event.get('httpMethod', '')
    path_params = event.get('pathParameters') or {}

    print(f"🔧 Método HTTP: {method}")
    print(f"📦 pathParameters: {path_params}")

    # Si hay image_id en la ruta
    if 'image_id' in path_params:
        raw_image_id = path_params.get('image_id')
        image_id = urllib.parse.unquote(raw_image_id)

        if not image_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({"error": "Missing image_id"})
            }

        # Normalizar si no tiene prefijo
        if not image_id.startswith("uploads/"):
            image_id = f"uploads/{image_id}"

        if method == 'GET':
            try:
                response = table.get_item(Key={'image_id': image_id})
                item = response.get('Item')

                if not item:
                    return {
                        'statusCode': 404,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({"error": "Image not found"})
                    }

                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(item, default=str)
                }

            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({"error": "Internal server error", "details": str(e)})
                }

        elif method == 'DELETE':
            try:
                table.delete_item(Key={'image_id': image_id})
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({"message": f"Metadata for '{image_id}' deleted successfully"})
                }

            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({"error": "Internal server error", "details": str(e)})
                }

    # Si no hay image_id → listar todos
    if method == 'GET':
        try:
            response = table.scan()
            items = response.get('Items', [])
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(items, default=str)
            }

        except Exception as e:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({"error": "Internal server error", "details": str(e)})
            }

    # Si el método no es válido
    return {
        'statusCode': 405,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({"error": f"Method {method} not allowed"})
    }

