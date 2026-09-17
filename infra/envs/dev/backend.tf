# partial backend - real values in backend.hcl.
# apply: terraform init -backend-config=backend.hcl
# review: terraform init -backend=false
terraform {
  backend "s3" {}
}
