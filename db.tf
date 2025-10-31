# --------------------------
# Database Subnet Group
# --------------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [
    aws_subnet.private_db_subnet_a.id,
    aws_subnet.private_db_subnet_b.id
  ]

  tags = {
    Name = "db-subnet-group"
  }
}




# --------------------------
# Database Instance (MySQL)
# --------------------------
resource "aws_db_instance" "db" {
  identifier              = "soar-db"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  username                = var.db_user
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name  # <- correcte reference
  vpc_security_group_ids  = [aws_security_group.db_sg.id]

  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  storage_type            = "gp2"

  tags = {
    Name        = "soar-db"
    Environment = var.environment
  }
}
 

output "db_endpoint" {
  value = aws_db_instance.db.endpoint
}
