variable "aws_region" {
  description = "The AWS region to deploy to"
  default     = "ap-northeast-2"
}

variable "profile" {
  description = "The AWS profile to use"
  default     = "dev"
}

# pointcloud processing requires some pre-installed packages like meditlink, autotest, etc.
# this pre-installed package is big size(over 6GB) and takes a long time to install.
# so, we use custom AMI for this project.
variable "custom_ami_id" {
  description = "The name of the custom AMI to use"
  type        = string
  default     = "ami-0b974a2f26d4dad47"
}

# This is already created in dev env, use the existing key pair
# if you need private key, you can contact the devops team or byeongjin.lee@medit.com
variable "ec2_key_name" {
  description = "The name of the EC2 key pair to use"
  type        = string
  default     = "point-cloud-test"
}

# S3 bucket for api server code
variable "s3_bucket_name" {
  description = "The name of the S3 bucket for api.py"
  type        = string
  default     = "pointcloud-api-bucket"
}

# S3 key for api server code
variable "s3_key" {
  description = "The key of the S3 object for api.py"
  type        = string
  default     = "api.py"
}

# we need GPU instance for pointcloud processing
# so you can choose the instance type with GPU
variable "instance_type" {
  description = "The instance type to use for EC2 instances"
  default     = "g4dn.xlarge"
}

variable "desired_capacity" {
  description = "The desired number of EC2 instances in the ASG"
  default     = 1
}

variable "max_size" {
  description = "The maximum number of EC2 instances in the ASG"
  default     = 3
}

variable "min_size" {
  description = "The minimum number of EC2 instances in the ASG"
  default     = 1
}

# Don't change the subnet IDs unless you know what you're doing
variable "subnet_ids" {
  description = "The subnet IDs to deploy the EC2 instances into"
  type        = list(string)
  default     = ["subnet-004f4d83cf888e96d", "subnet-09fcd95b4cbf24f13"]
}

# Don't change the VPC ID unless you know what you're doing
variable "vpc_id" {
  description = "The ID of the VPC to deploy into"
  type        = string
  default     = "vpc-585abb33"
}

# This Infrastructure is only accessible from the specified CIDR blocks
# Becase thiis project is PoC and limited access is required
# You can add your office IP address here if you need to make some request to api server from your local machine
variable "ingress_cidr_blocks" {
  description = "The CIDR blocks to allow ingress traffic from"
  type        = list(string)
  default     = ["1.223.27.37/32"]
}

# I don't know what is proper value for this variable, need to estimate
variable "processing_time_threshold" {
  description = "The threshold for processing time to trigger scaling (in seconds)"
  default     = 3000
}
