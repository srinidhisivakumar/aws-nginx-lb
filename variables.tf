variable "region" {
  type        = string
  default     = "us-east-2" # or your preferred region
  description = "AWS region to deploy into"
}

variable "ami_id" {
  type        = string
  description = "Custom AMI with NGINX"
}

variable "key_name" {
  type        = string
  description = "Key pair for EC2 access"
}


