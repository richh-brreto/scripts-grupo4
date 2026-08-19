resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.azs[0]
  tags = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.azs[1]
  tags = { Name = "${var.project_name}-private-b" }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.azs[0]
  tags = { Name = "${var.project_name}-db" }
}
