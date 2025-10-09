variable "region" {
  description = "Region"
  type        = string
  default     = "eu-central-1" 
}

// SSH key
variable "ssh_key" {
  description = "ssh_key"
  type        = string
}

// EC2
variable "EC2_image" {
  description = "EC2_image"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu*22.04*" 
}

// Security
variable "ssh_port" {
  description = "SSH Port"
  type        = number
  default     = 22
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to connect over SSH"
  type        = string
  default     = "0.0.0.0/0" # (for testing; in production restrict to your IP)
}

variable "http_port" {
  description = "Port for HTTP traffic"
  type        = number
  default     = 80
}