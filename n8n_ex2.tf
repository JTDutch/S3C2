# -----------------------------
# N8N EC2 instance
# -----------------------------
resource "aws_instance" "n8n" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_app_subnet.id
  vpc_security_group_ids      = [aws_security_group.n8n_sg.id]
  key_name                    = aws_key_pair.demo_key.key_name
  associate_public_ip_address = true

user_data = <<-EOF
#!/bin/bash
set -e

# -----------------------------
# Update & install Docker
# -----------------------------
apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# -----------------------------
# Maak directory voor N8N met correcte permissies
# -----------------------------
mkdir -p /home/ubuntu/n8n
chown -R 1000:1000 /home/ubuntu/n8n

# -----------------------------
# Verwijder eventueel oude container
# -----------------------------
docker rm -f n8n || true

# -----------------------------
# Start N8N container
# -----------------------------
docker run -d \
  --name n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=changeme \
  -e N8N_SECURE_COOKIE=false \
  -e N8N_HOST=n8n.internal.example.com \
  -e N8N_PORT=5678 \
  -e N8N_METRICS=true \
  -e N8N_METRICS_PORT=5678 \
  -e N8N_RUNNERS_ENABLED=true \
  -e DB_SQLITE_POOL_SIZE=2 \
  -v /home/ubuntu/n8n:/home/node/.n8n \
  -p 5678:5678 \
  --restart always \
  n8nio/n8n:latest
EOF

  tags = {
    Name        = "n8n-${var.environment}"
    Environment = var.environment
  }
}

# -----------------------------
# Private DNS record voor N8N
# -----------------------------
resource "aws_route53_record" "n8n" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "n8n.internal.example.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.n8n.private_ip]
}
