import boto3
import os
import json

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    
    # Get uploaded file details
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    print(f"Processing file: {file_key} from {bucket_name}")
    
    # Read file
    response = s3.get_object(Bucket=bucket_name, Key=file_key)
    content = response['Body'].read().decode('utf-8')
    line_count = len(content.splitlines())
    
    # Create Summary
    summary = {
        "original_file": file_key,
        "line_count": line_count,
        "status": "processed"
    }
    
    # Save to Processed Bucket
    dest_bucket = os.environ['PROCESSED_BUCKET']
    dest_key = f"summary-{file_key}.json"
    
    s3.put_object(
        Bucket=dest_bucket,
        Key=dest_key,
        Body=json.dumps(summary)
    )
    return {"status": "success", "file": dest_key}