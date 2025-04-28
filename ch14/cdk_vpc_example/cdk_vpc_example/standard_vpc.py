from constructs import Construct
from aws_cdk import (
    aws_ec2 as ec2,
    Tags,
    Stack
)
from typing import List, Optional

class StandardVpc(Construct):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        project_name: str,
        vpc_cidr: str = "10.0.0.0/16",
        public_subnet_cidrs: Optional[List[str]] = None,
        private_subnet_cidrs: Optional[List[str]] = None,
        **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.project_name = project_name
        # Set default CIDR ranges if not provided
        self.public_subnet_cidrs = public_subnet_cidrs or [
            "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"
        ]
        self.private_subnet_cidrs = private_subnet_cidrs or [
            "10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"
        ]
        self.region = Stack.of(self).region

        # Create the VPC
        self.vpc = ec2.Vpc(
            self,
            "StandardVPC",
            vpc_name=f"{self.project_name}-{self.region}-vpc",
            ip_addresses=ec2.IpAddresses.cidr(vpc_cidr),
            max_azs=3,
            subnet_configuration=[],  # We'll create subnets manually
            enable_dns_hostnames=True,
            enable_dns_support=True,
        )

        # Create public subnets
        self.public_subnets = []
        for i, cidr in enumerate(self.public_subnet_cidrs):
            subnet = ec2.Subnet(
                self,
                f"PublicSubnet{i+1}",
                vpc_id=self.vpc.vpc_id,
                availability_zone=self.vpc.availability_zones[i],
                cidr_block=cidr,
                map_public_ip_on_launch=True,
            )
            self.public_subnets.append(subnet)
            Tags.of(subnet).add(
                "Name", f"{self.project_name}-{self.region}-public-subnet-{i+1}"
            )

        # Create private subnets
        self.private_subnets = []
        for i, cidr in enumerate(self.private_subnet_cidrs):
            subnet = ec2.Subnet(
                self,
                f"PrivateSubnet{i+1}",
                vpc_id=self.vpc.vpc_id,
                availability_zone=self.vpc.availability_zones[i],
                cidr_block=cidr,
                map_public_ip_on_launch=False,
            )
            self.private_subnets.append(subnet)
            Tags.of(subnet).add(
                "Name", f"{self.project_name}-{self.region}-private-subnet-{i+1}"
            )

        # Create and attach Internet Gateway
        self.igw = ec2.CfnInternetGateway(
            self,
            "InternetGateway",
            tags=[{"key": "Name", "value": f"{self.project_name}-{self.region}-igw"}]
        )

        ec2.CfnVPCGatewayAttachment(
            self,
            "IGWAttachment",
            vpc_id=self.vpc.vpc_id,
            internet_gateway_id=self.igw.ref
        )

        # Create public route table
        self.public_route_table = ec2.CfnRouteTable(
            self,
            "PublicRouteTable",
            vpc_id=self.vpc.vpc_id,
            tags=[{"key": "Name", "value": f"{self.project_name}-{self.region}-public-rt"}]
        )

        # Add route to Internet Gateway in public route table
        ec2.CfnRoute(
            self,
            "PublicRoute",
            route_table_id=self.public_route_table.ref,
            destination_cidr_block="0.0.0.0/0",
            gateway_id=self.igw.ref
        )
        # Associate public subnets with public route table
        for i, subnet in enumerate(self.public_subnets):
            ec2.CfnSubnetRouteTableAssociation(
                self,
                f"PublicSubnetRouteTableAssociation{i+1}",
                subnet_id=subnet.subnet_id,
                route_table_id=self.public_route_table.ref
            )

        # Create private route tables
        self.private_route_tables = []
        for i in range(3):
            route_table = ec2.CfnRouteTable(
                self,
                f"PrivateRouteTable{i+1}",
                vpc_id=self.vpc.vpc_id,
                tags=[{
                    "key": "Name",
                    "value": f"{self.project_name}-{self.region}-private-rt-{i+1}"
                }]
            )
            self.private_route_tables.append(route_table)


        # Associate private subnets with private route tables
        for i, subnet in enumerate(self.private_subnets):
            ec2.CfnSubnetRouteTableAssociation(
                self,
                f"PrivateSubnetRouteTableAssociation{i+1}",
                subnet_id=subnet.subnet_id,
                route_table_id=self.private_route_tables[i].ref
            )
