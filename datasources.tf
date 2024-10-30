data "aws_ami" "ec2_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # Patrón de nombre para Amazon Linux 2
  }
  
  owners = ["137112412989"]
}


data "aws_caller_identity" "current" {}


data "aws_iam_role" "labrole" {
  name = "labrole"  # Cambia esto por el nombre de tu rol
}