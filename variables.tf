variable "access_key" {
  description = "The AWS access key."
}

variable "secret_key" {
  description = "The AWS secret key."
}

variable "region" {
  description = "The AWS region to create resources in."
  default     = "eu-west-2"
}

variable "profile" {
  description = "The AWS profile."
  default     = "mytf"
}

variable "dns_zone_id" {
  description = "The AWS identifier for the hosted zone to add names to"
}

variable "dns_root" {
  description = "The domain or subdomain to create names in"
  default     = "aws.example.com"
}

variable "availability_zones" {
  description = "The availability zone"
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "ecs_cluster_name" {
  description = "The name of the Amazon ECS cluster."
  default     = "jenkins"
}

variable "amis" {
  description = "Which AMI to spawn. Defaults to the AWS ECS optimized images."

  default = {
    us-east-1      = "ami-8f7687e2"
    us-west-1      = "ami-bb473cdb"
    us-west-2      = "ami-84b44de4"
    eu-west-1      = "ami-4e6ffe3d"
    eu-west-2      = "ami-2218f945"
    eu-central-1   = "ami-b0cc23df"
    ap-northeast-1 = "ami-095dbf68"
    ap-southeast-1 = "ami-cf03d2ac"
    ap-southeast-2 = "ami-697a540a"
  }
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  default     = "myawskey"
  description = "SSH key name in your AWS account for AWS instances."
}

variable "min_instance_size" {
  default     = 1
  description = "Minimum number of EC2 instances."
}

variable "max_instance_size" {
  default     = 2
  description = "Maximum number of EC2 instances."
}

variable "desired_instance_capacity" {
  default     = 2
  description = "Desired number of EC2 instances."
}

variable "desired_service_count" {
  default     = 1
  description = "Desired number of ECS services."
}

variable "s3_bucket" {
  default     = "mycompany-jenkins"
  description = "S3 bucket where remote state and Jenkins data will be stored."
}

variable "restore_backup" {
  default     = false
  description = "Whether or not to restore Jenkins backup."
}

variable "jenkins_repository_url" {
  default     = "jenkins"
  description = "ECR Repository for Jenkins."
}

variable "namespace" {
  type        = "string"
  description = "Namespace, which could be your organization name, e.g. 'cp' or 'cloudposse'"
}

variable "jenkins_home" {
  type        = "string"
  description = "Jenkins home directory."
  default     = "/var/jenkins_home"
}

variable "name" {
  type        = "string"
  description = "Solution name, e.g. 'app' or 'jenkins'"
  default     = "jenkins"
}

variable "stage" {
  type        = "string"
  description = "Stage, e.g. 'prod', 'staging', 'dev', or 'test'"
}

variable "delimiter" {
  type        = "string"
  default     = "-"
  description = "Delimiter to be used between `name`, `namespace`, `stage`, etc."
}

variable "attributes" {
  type        = "list"
  default     = []
  description = "Additional attributes (e.g. `policy` or `role`)"
}

variable "tags" {
  type        = "map"
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
}

variable "noncurrent_version_expiration_days" {
  type        = "string"
  default     = "35"
  description = "Backup S3 bucket noncurrent version expiration days"
}

variable "datapipeline_config" {
  type        = "map"
  description = "DataPipeline configuration options"

  default = {
    instance_type = "t2.micro"
    email         = ""
    period        = "24 hours"
    timeout       = "60 Minutes"
  }
}

variable "use_efs_ip_address" {
  default = "false"
}
