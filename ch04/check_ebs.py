import boto3

ec2_client = boto3.client("ec2")

for region in ec2_client.describe_regions()["Regions"]:
    region_name = region["RegionName"]
    print(f"Checking volumes in {region_name}")
    
    ec2_resource = boto3.resource("ec2", region_name=region_name)

    unattached = ec2_resource.volumes.filter(Filters=[{
        "Name": "status",
        "Values": ["available"]
    }])

    for vol in unattached:
        v = ec2_resource.Volume(vol.id)
        snap = v.create_snapshot()
        print(f"Snapshot of {v.id} taken as {snap.id}. Deleting the volume.")
        v.delete()
