import json
import boto3
import base64
import os

s3 = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

def response(status, payload):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(payload)
    }

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters') or {}
        file_name = query_params.get('filename')

        if not file_name:
            return response(400, {'error': 'O parametro filename e obrigatorio na URL (?filename=exemplo.txt)'})

        body = event.get('body') or ''

        if event.get('isBase64Encoded', False):
            file_content = base64.b64decode(body)
        else:
            file_content = body.encode('utf-8') if isinstance(body, str) else body

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=file_content
        )

        return response(200, {'message': f'Arquivo {file_name} salvo com sucesso no S3!'})
    except Exception as e:
        return response(500, {'error': str(e)})
