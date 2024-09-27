import os
import json
import boto3

SECRET_ARN = os.environ.get("SECRET_ARN")
sm_client = boto3.client("secretsmanager")

def handler(event, context):
    resp = sm_client.get_secret_value(SecretId=SECRET_ARN)

    secret_obj = json.loads(resp["SecretString"])
    return "Read password: " + secret_obj["Password"] + " Read username: " + secret_obj["Username"]