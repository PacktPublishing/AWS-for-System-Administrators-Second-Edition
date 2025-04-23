# Create RAM share
resource "aws_ram_resource_share" "subnet_share" {
  name                      = "private-subnets-share"
  allow_external_principals = false

  tags = {
    Name = "private-subnets-share"
  }
}

# Share private subnets
resource "aws_ram_resource_association" "subnet_share" {
  count              = length(aws_subnet.private)
  resource_arn       = aws_subnet.private[count.index].arn
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
}

# Associate share with OU
resource "aws_ram_principal_association" "ou_share" {
  principal          = aws_organizations_organizational_unit.test.arn
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
}