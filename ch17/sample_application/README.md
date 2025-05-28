> [!CAUTION]
> This example deploys actual infrastructure that costs money. **Remember to log into the deployment accounts and destroy the resources (like the Aurora Cluster) to avoid charges**
### IAM Policy for deployment

The `policy.json` file provides a reasonably restricted set of permissions needed to deploy the Terraform configuration. However, for production environments, you could further restrict this policy to adhere to the principle of least privilege.

### Tightening S3 and DynamoDB Permissions

The current policy allows access to any S3 bucket and DynamoDB table. We require this access to get access to the S3 bucket and dynamodb table that hold the tf state, which is convenient but not ideal for least privilege. Here's how you can restrict these permissions to only the specific resources needed:

#### Example of a more restrictive S3 and DynamoDB policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-specific-bucket-name/prod/terraform.tfstate"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-specific-bucket-name"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:your-region:your-account-id:table/terraform-lock-table"
    }
  ]
}
```

Replace the following placeholders:
- `your-specific-bucket-name`: The exact name of your Terraform state bucket
- `your-region`: The AWS region where the DynamoDB table is located
- `your-account-id`: Your 12-digit AWS account ID

### Additional Security Improvements

1. **Resource-Specific RDS Permissions**:
   Instead of allowing all RDS actions on all resources, you can restrict to specific Aurora cluster resources:

   ```json
   {
     "Effect": "Allow",
     "Action": [
       "rds:CreateDBCluster",
       "rds:DeleteDBCluster",
       "rds:DescribeDBClusters",
       "rds:ModifyDBCluster"
     ],
     "Resource": "arn:aws:rds:your-region:your-account-id:cluster:aurora-cluster"
   }
   ```

2. **KMS Key Restrictions**:
   Once a KMS key is created, you can update your policy to restrict to that specific key:

   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:DescribeKey",
       "kms:GenerateDataKey",
       "kms:Decrypt",
       "kms:Encrypt"
     ],
     "Resource": "arn:aws:kms:your-region:your-account-id:key/key-id"
   }
   ```

## Cleaning Up

To avoid incurring charges, destroy all resources when no longer needed:
```
terraform destroy
```
