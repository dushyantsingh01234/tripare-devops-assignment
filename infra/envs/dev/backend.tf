# the plan is s3 + dynamodb locking, values in backend.hcl.
# left commented out so `terraform init` works out-of-the-box for review
# (defaults to local state). uncomment + run:
#   terraform init -backend-config=backend.hcl -reconfigure
# when you actually want to point at the remote backend.
#
# terraform {
#   backend "s3" {}
# }
