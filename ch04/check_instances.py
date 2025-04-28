import boto3

ec2_client = boto3.client("ec2")

for region in ec2_client.describe_regions()["Regions"]:
    region_name = region["RegionName"]
    print(f"Checking instances in {region_name}")
    ec2_resource = boto3.resource("ec2", region_name=region_name)

    running = ec2_resource.instances.filter(Filters=[{
        "Name": "instance-state-name",
        "Values": ["running"]
    }])

    for i in running:
        for tag in i.tags:
            if tag["Key"] == "shutdown-group" and tag["Value"] == "dev":
                print(f"Stopping instance with id {i.id}")
                #i.stop()
