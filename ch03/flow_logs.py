import boto3
from botocore.exceptions import ClientError

ec2_client = boto3.client("ec2")
logs_client = boto3.client("logs")

ROLE_ARN = "arn:aws:iam::317322385701:role/VpcFlowLogRole"

def log_group_exists(log_group_name):
    resp = logs_client.describe_log_groups(logGroupNamePrefix=log_group_name)

    return len(resp["logGroups"]) > 0

def create_log_group(log_group_name):
    try:
        resp = logs_client.create_log_group(logGroupName=log_group_name)
    except ClientError:
        raise Exception("Unable to create log group")

def create_flow_logs(vpc_id, log_group_name):
    resp = ec2_client.create_flow_logs(ResourceIds=[vpc_id],
                                       ResourceType="VPC",
                                       TrafficType="ALL",
                                       LogGroupName=log_group_name,
                                       DeliverLogsPermissionArn=ROLE_ARN)
def flow_logs_enabled(vpc_id):
    resp = ec2_client.describe_flow_logs(
        Filter=[
            {
                "Name": "resource-id",
                "Values": [
                    vpc_id,
                ]
            },
        ]
    )

    return len(resp["FlowLogs"]) > 0

def main():
    vpc_id = input("VpcId: ")
    vpc_has_flow_logs = flow_logs_enabled(vpc_id)

    if not vpc_has_flow_logs:
        print("Enabling flow logs")
        log_group_name = f"{vpc_id}-flow-logs"
        if not log_group_exists(log_group_name):
            print("Creating new log group")
            create_log_group(log_group_name)
        create_flow_logs(vpc_id, log_group_name)
    else:
        print("Flow logs already enabled")
        


if __name__ == "__main__":
    main()