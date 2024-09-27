import boto3
client = boto3.client("sts")
resp = client.get_caller_identity()
print(resp)

