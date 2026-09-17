variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:1.27"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type = number
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
