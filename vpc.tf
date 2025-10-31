# --------------------------
# VPC
# --------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "soar-vpc"
    Environment = "dev"
  }
}

# --------------------------
# PUBLIC SUBNETS (Load Balancer)
# --------------------------
resource "aws_subnet" "public_lb_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az1
  map_public_ip_on_launch = true

  tags = {
    Name = "soar-public-lb-subnet-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_lb_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az2
  map_public_ip_on_launch = true

  tags = {
    Name = "soar-public-lb-subnet-b"
    Tier = "public"
  }
}

# --------------------------
# API + SOAR SUBNET (nu public)
# --------------------------
resource "aws_subnet" "public_app_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = var.az1
  map_public_ip_on_launch = true

  tags = {
    Name = "soar-public-app-subnet"
    Tier = "public"
  }
}

# --------------------------
# PRIVATE DB SUBNET
# --------------------------
resource "aws_subnet" "private_db_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = var.az1
  map_public_ip_on_launch = false

  tags = {
    Name = "soar-private-db-subnet"
    Tier = "private"
  }
}

resource "aws_subnet" "private_db_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.22.0/24"
  availability_zone       = var.az2
  map_public_ip_on_launch = false

  tags = {
    Name = "soar-private-db-subnet-b"
    Tier = "private"
  }
}

# --------------------------
# INTERNET GATEWAY
# --------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "soar-igw"
  }
}

# --------------------------
# PUBLIC ROUTE TABLE
# --------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "soar-public-rt"
  }
}

# Associate public subnets
resource "aws_route_table_association" "public_lb_assoc_a" {
  subnet_id      = aws_subnet.public_lb_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_lb_assoc_b" {
  subnet_id      = aws_subnet.public_lb_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_app_assoc" {
  subnet_id      = aws_subnet.public_app_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# --------------------------
# PRIVATE ROUTE TABLE (DB only)
# --------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "soar-private-rt"
  }
}

# Associate private DB subnets
resource "aws_route_table_association" "private_db_assoc_a" {
  subnet_id      = aws_subnet.private_db_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_db_assoc_b" {
  subnet_id      = aws_subnet.private_db_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Route 53
resource "aws_route53_zone" "private" {
  name          = "internal.example.com"   # Kies een interne domeinnaam
  vpc {
    vpc_id = aws_vpc.main.id               # Je VPC ID
  }
}
