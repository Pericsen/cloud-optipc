data "aws_ami" "ec2_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  
  }
  
  owners = ["137112412989"]
}


data "aws_caller_identity" "current" {}


data "aws_iam_role" "labrole" {
  name = "labrole"  
}

data "klayers_package_latest_version" "pandas" {
  name   = "pandas"
  region = "us-east-1"
}