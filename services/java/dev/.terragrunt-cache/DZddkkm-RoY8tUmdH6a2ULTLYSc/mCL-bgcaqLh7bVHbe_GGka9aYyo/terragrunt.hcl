include {
  path = find_in_parent_folders()
}

inputs = {
  region = "us-east-1"
  environment = "dev"

microservice_name = "java-ms"
health_check_path = "/"
load_balancer_arn = "arn:aws:elasticloadbalancing:us-east-1:211125593418:loadbalancer/app/cloud-devops-alb/0a99c5d8704fbba8"
listener_arn = "arn:aws:elasticloadbalancing:us-east-1:211125593418:listener/app/cloud-devops-alb/0a99c5d8704fbba8/083e80da22e57219"
pattern_value = ["/api/*"]
lb_security_groups = "sg-0b0c9c10769180f8b"
app_port = "8080"
vpc_id =  "vpc-0f84b492e0a2e540a"
execution_role_arn =  "arn:aws:iam::211125593418:role/cloud-devops-ecs-task-exec-role"
ecs_cluster =  "cloud-devops-cluster"
app_count = "1"
subnets = ["subnet-08cc46fce8a8d4956", "subnet-045d7ee92ae911349", "subnet-01f6e033d2edd688b"]

}