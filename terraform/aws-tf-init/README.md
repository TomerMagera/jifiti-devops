### Intializing aws for terraform
Basically it just creates the s3 bucket that will serve us as the s3 backend to keep the terraform state file of our EKS application terraform configuration.

It also contains code for the creation of DynamoDB tables, that are used state file locking by terraform, but in the sandbox user doesn't have perms for that, so no such tables are created.

The tf state for this configuration is kept locally only.

Run command:
```bash
tf init

tf plan

tf apply 
```