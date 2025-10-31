# ✅ Launch template (recipe for EC2 instances)
resource "aws_launch_template" "web_lt" {
  name_prefix   = "webserver-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.demo_key.key_name

  vpc_security_group_ids = [
    aws_security_group.port_22.id,
    aws_security_group.web_sg.id
  ]

  user_data = base64encode(<<EOT
#!/bin/bash
set -e

# -----------------------------
# Update & install base packages
# -----------------------------
apt-get update -y
apt-get install -y apache2 php php-mysql curl unzip wget docker.io docker-compose

# -----------------------------
# Enable Apache mod_status for monitoring
# -----------------------------
sudo a2enmod status
sudo tee /etc/apache2/conf-available/status.conf > /dev/null <<EOF
<Location /server-status>
    SetHandler server-status
    Require all granted
</Location>
EOF
sudo a2enconf status
sudo systemctl reload apache2

# -----------------------------
# Create index.php that calls the API server
# -----------------------------
API_IP="${aws_instance.api_server.private_ip}"

sudo tee /var/www/html/index.php > /dev/null <<EOF
<?php
header('Content-Type: text/html');

// API endpoint using private IP from Terraform
\$api_ip = "${aws_instance.api_server.private_ip}";
\$api_url = "http://\$api_ip/api.php?action=get_all";

// Fetch JSON from API
\$response = @file_get_contents(\$api_url);
if (\$response === FALSE) {
    echo "Error contacting API server at \$api_url.";
} else {
    \$data = json_decode(\$response, true);
    echo "<pre>";
    print_r(\$data);
    echo "</pre>";
}
?>
EOF

sudo rm -f /var/www/html/index.html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
sudo systemctl enable apache2
sudo systemctl restart apache2

# -----------------------------
# Setup Docker Compose for Prometheus + Node Exporter + Apache Exporter
# -----------------------------
mkdir -p /opt/monitoring
cd /opt/monitoring

cat > docker-compose.yml <<'COMPOSE'
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: always

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    restart: always

  apache_exporter:
    image: lusotycoon/apache-exporter:latest
    network_mode: "host"
    command:
      - '--scrape_uri=http://127.0.0.1/server-status?auto'
    restart: always
COMPOSE

# Prometheus config
cat > prometheus.yml <<'PROM'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    ec2_sd_configs:
      - region: eu-west-1
        port: 9100
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: webserver.*
        action: keep

  - job_name: 'apache_exporter'
    ec2_sd_configs:
      - region: eu-west-1
        port: 9117
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: webserver.*
        action: keep
PROM

docker-compose up -d
EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "webserver"
      Environment = "dev"
    }
  }
}



# ✅ Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                = "webserver-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 5
  vpc_zone_identifier = [aws_subnet.public_lb_subnet_a.id, aws_subnet.public_lb_subnet_b.id]
  health_check_type   = "EC2"
  force_delete        = true

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.soar_tg.arn]

  tag {
    key                 = "Name"
    value               = "webserver"
    propagate_at_launch = true
  }
}

# ✅ Scaling policies
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# ✅ CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "webserver-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "webserver-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  treat_missing_data = "notBreaching"
}
