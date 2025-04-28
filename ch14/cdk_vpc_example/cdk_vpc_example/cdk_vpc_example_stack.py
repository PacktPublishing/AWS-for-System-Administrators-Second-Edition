from aws_cdk import (
    # Duration,
    Stack,
    # aws_sqs as sqs,
)
from constructs import Construct
from cdk_vpc_example.standard_vpc import StandardVpc

class CdkVpcExampleStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        vpc = StandardVpc(self, "standard_vpc", 
                          project_name="test-cdk-project",
                          vpc_cidr="10.30.0.0/16",
                          public_subnet_cidrs=[
                              "10.30.1.0/24",
                              "10.30.2.0/24",
                              "10.30.3.0/24"
                          ],
                          private_subnet_cidrs=[
                              "10.50.1.0/24",
                              "10.50.2.0/24",
                              "10.50.3.0/24"
                          ])
