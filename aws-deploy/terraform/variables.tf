variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.medium"
}

variable "ebs_volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "minecraft_memory" {
  description = "Memory allocation for Minecraft server in MB"
  type        = number
  default     = 3072
}

variable "discord_webhook_url" {
  description = "Discord Webhook URL for notifications"
  type        = string
  default     = ""
}


variable "discord_bot_url" {
  description = "Discord Bot URL (Railway.app)"
  type        = string
  default     = ""
}
