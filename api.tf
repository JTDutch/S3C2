# ✅ IAM Role for Prometheus EC2 Discovery
resource "aws_iam_role" "prometheus_role" {
  name = "prometheus-ec2-discovery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "sts:AssumeRole"
      Effect   = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "prometheus_ec2_policy" {
  name = "prometheus-ec2-policy"
  role = aws_iam_role.prometheus_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "prometheus-ec2-profile"
  role = aws_iam_role.prometheus_role.name
}

# ✅ API Server EC2
resource "aws_instance" "api_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.demo_key.key_name
  subnet_id                   = aws_subnet.public_app_subnet.id
  vpc_security_group_ids      = [aws_security_group.api_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.prometheus_profile.name

user_data = base64encode(<<EOT
#!/bin/bash
set -e

# -----------------------------
# Update & install base packages
# -----------------------------
apt-get update -y
apt-get install -y apache2 php php-mysql curl unzip docker.io docker-compose

# -----------------------------
# Create API PHP file
# -----------------------------
cat <<EOF > /var/www/html/api.php
<?php
header('Content-Type: application/json');

\$servername = "${aws_db_instance.db.endpoint}";
\$port       = "${aws_db_instance.db.port}";
\$username   = "${var.db_user}";
\$password   = "${var.db_password}";
\$dbname     = "${var.db_name}";

\$conn = new mysqli(\$servername, \$username, \$password, \$dbname, \$port);

if (\$conn->connect_error) {
    die(json_encode(["error" => "Connection failed: " . \$conn->connect_error]));
}

if (isset(\$_GET['action']) && \$_GET['action'] === 'get_all') {
    \$result = \$conn->query("SELECT * FROM users");
    \$rows = [];
    while(\$row = \$result->fetch_assoc()) {
        \$rows[] = \$row;
    }
    echo json_encode(\$rows);
}

\$conn->close();
?>
EOF

sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl enable docker
sudo systemctl start docker

# -----------------------------
# Monitoring stack setup
# -----------------------------
mkdir -p /opt/monitoring/grafana/provisioning/{datasources,dashboards}

# Docker Compose
cat > /opt/monitoring/docker-compose.yml <<'COMPOSE'
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
      - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards
    restart: always

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    restart: always

volumes:
  grafana-storage:
COMPOSE


PROM

# Grafana datasource
cat > /opt/monitoring/grafana/provisioning/datasources/datasource.yml <<'DATASOURCE'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
DATASOURCE

# Grafana dashboard provider
cat > /opt/monitoring/grafana/provisioning/dashboards/dashboard.yml <<'DASH'
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
DASH

# -----------------------------
# Webservers Overview dashboard (CPU + Uptime + Apache Online)
# -----------------------------
cat > /opt/monitoring/grafana/provisioning/dashboards/webservers_overview.json <<'DASHWEB'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "axisSoftMax": 100,
            "axisSoftMin": 0,
            "barAlignment": 0,
            "barWidthFactor": 0.6,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "showValues": false,
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "12.2.1",
      "targets": [
        {
          "expr": "100 - (avg by (instance)(irate(node_cpu_seconds_total{job=\"node_exporter\",mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "CPU Usage per Webserver",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 11,
        "x": 0,
        "y": 9
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "12.2.1",
      "targets": [
        {
          "expr": "up{job=\"node_exporter\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "Uptime per Webserver",
      "type": "stat"
    },
    {
      "datasource": {
        "uid": "PBFA97CFB590B2093"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 7,
        "w": 11,
        "x": 0,
        "y": 12
      },
      "id": 3,
      "options": {
        "displayMode": "gradient",
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "maxVizHeight": 300,
        "minVizHeight": 16,
        "minVizWidth": 8,
        "namePlacement": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showUnfilled": true,
        "sizing": "auto",
        "valueMode": "color"
      },
      "pluginVersion": "12.2.1",
      "targets": [
        {
          "editorMode": "code",
          "expr": "up{job=\"apache_exporter\"}\r\n",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Status Apache Service",
      "type": "bargauge"
    }
  ],
  "preload": false,
  "schemaVersion": 42,
  "tags": [
    "webserver"
  ],
  "templating": {
    "list": []
  },
  "timepicker": {},
  "timezone": "",
  "title": "Webservers Overview",
  "uid": "webservers-overview",
  "version": 1
}
DASHWEB

# Start monitoring stack
cd /opt/monitoring


# Prometheus config with EC2 service discovery for Node Exporter + Apache Exporter
cat > /opt/monitoring/prometheus.yml <<'PROM'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'apache_exporter'
    ec2_sd_configs:
      - region: eu-west-1
        port: 9117    # Apache Exporter poort
        refresh_interval: 1m
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: webserver
        action: keep

  - job_name: 'node_exporter'
    ec2_sd_configs:
      - region: eu-west-1
        port: 9100
        refresh_interval: 1m
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        regex: webserver
        action: keep


docker-compose up -d
EOT
)

}
