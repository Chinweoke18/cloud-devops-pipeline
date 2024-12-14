
terraform {
  source = "${get_parent_terragrunt_dir()}/tf"
}

inputs = {
  script_path = "${get_parent_terragrunt_dir()}/scripts/service.json.tpl"
  cluster_name = "cloud-devops-cluster"
}