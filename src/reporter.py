import boto3
import os
import json

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    
    bucket = os.environ['PROCESSED_BUCKET']
    topic_arn = os.environ['SNS_TOPIC_ARN']
    
    # List all summaries
    response = s3.list_objects_v2(Bucket=bucket)
    total_files = response.get('KeyCount', 0)
    
    message = f"Daily Report:\nTotal files processed: {total_files}\n"
    
    # Publish to SNS
    sns.publish(
        TopicArn=topic_arn,
        Message=message,
        Subject="Daily Data Pipeline Report"
    )
    return {"status": "report_sent"}