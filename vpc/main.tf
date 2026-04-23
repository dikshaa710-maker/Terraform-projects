provider "aws"{
  region = var.region
}
data "aws_ami" "ami"
{

}
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = { Name = "public-${count.index}" }
}

resource "aws_internet_gateway" "main-vpc-igw" {
    vpc_id = aws_vpc.main.id

  
}
data "aws_availability_zones" "azs" {}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.vpc_cidr
    gateway_id = aws_internet_gateway.main-vpc-igw.id
  }
}
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_s3_bucket" "demo-buck" {
 bucket = "dikshaa710-demo-buck"  
 
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = aws_vpc.main.id

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = [aws_route_table.public-rt.id]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_policy" {
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "profile" {
  role = aws_iam_role.ec2_role.name
}

 
resource "aws_instance" "private_ec2" {
  ami           = "ami-0f58b397bc5c1f2e8" # change based on region
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private[0].id

  iam_instance_profile = aws_iam_instance_profile.profile.name

  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              yum install -y aws-cli
              aws s3 ls
              EOF

  tags = {
    Name = "private-ec2"
  }
}