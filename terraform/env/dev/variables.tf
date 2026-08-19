variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "developer_ip_cidr" {
  type        = string
  description = "CIDR for developer machine accessing EKS endpoint"
}
