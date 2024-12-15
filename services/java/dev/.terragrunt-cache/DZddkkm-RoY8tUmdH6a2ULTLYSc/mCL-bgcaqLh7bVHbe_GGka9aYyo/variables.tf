variable "region" {
  type        = string
}

variable "subnets" {
  type        = list(string)
  default     = []
}

variable "microservice_name" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "script_path" {
  type        = string
}

variable "health_check_path" {
  type        = string
}


variable "load_balancer_arn" {
  type        = string
}


variable "app_port" {
  type        = string
}


variable "lb_security_groups" {
  type        = string
}

variable "listener_arn" {
  type        = string
}

variable "pattern_value" {
  type        =  list(string)
}

variable "execution_role_arn" {
  type        = string
}

variable "ecs_cluster" {
  type        = string
}
variable "app_count" {
  type        = string
}

# variable "ecs_service" {
#   type        = string
# }

variable "fargate_cpu" {
  type        = string
  default     = "512"
}

variable "fargate_memory" {
  type        = string
  default     = "1024"
}

variable "app_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "nginx:latest"
}



