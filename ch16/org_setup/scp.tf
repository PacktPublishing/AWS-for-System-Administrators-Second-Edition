resource "aws_organizations_policy" "ec2_region_on_allowed" {
  name = "ec2-region-restriction"
  description = "Restricts EC2 instance launch to allowed regions"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DenyEC2LaunchOutsideAllowedRegions"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:StartInstances",
          "ec2:StartInstance*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "eu-central-1",
              "eu-west-1"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "ec2_region_only_allowed_to_workloads" {
  policy_id = aws_organizations_policy.ec2_region_on_allowed.id
  target_id = aws_organizations_organizational_unit.workloads.id
}