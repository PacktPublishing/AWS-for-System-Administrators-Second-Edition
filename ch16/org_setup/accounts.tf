resource "aws_organizations_account" "test_account" {
  name      = "test-acc"
  email     = "mn+workloads-test-acc@nlogn.org"
  parent_id = aws_organizations_organizational_unit.test.id

  # Important: Account cannot be destroyed by Terraform
  # Set close_on_deletion to true only if you want the account closed when removed from Terraform
  close_on_deletion = false
}