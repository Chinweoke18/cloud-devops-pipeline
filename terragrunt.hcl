
terraform {
  source = "${get_parent_terragrunt_dir()}/tf"
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "cloud-pipeline-tfrm-state-d0f9670e"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloud-devops-pipeline-tform-lock-table"
  }

}
locals {
  auto_approve = true
}

inputs = {
  script_path = "${get_parent_terragrunt_dir()}/scripts/service.json.tpl"
  cluster_name = "cloud-devops-cluster"
}