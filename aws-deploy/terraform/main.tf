# AWS Minecraft Server Terraform Configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# セキュリティグループ
resource "aws_security_group" "minecraft" {
  name        = "minecraft-server-sg"
  description = "Security group for Minecraft server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minecraft-server-sg"
  }
}

# EC2インスタンス用IAMロール
resource "aws_iam_role" "minecraft_instance" {
  name = "minecraft-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# EC2インスタンス用ポリシー（自己停止権限 + SSM Parameter Store）
resource "aws_iam_role_policy" "minecraft_instance_policy" {
  name = "minecraft-instance-policy"
  role = aws_iam_role.minecraft_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/minecraft/*"
      }
    ]
  })
}

# SSM用のマネージドポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "minecraft_ssm" {
  role       = aws_iam_role.minecraft_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# インスタンスプロファイル
resource "aws_iam_instance_profile" "minecraft" {
  name = "minecraft-instance-profile"
  role = aws_iam_role.minecraft_instance.name
}

# EC2インスタンス
resource "aws_instance" "minecraft" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  iam_instance_profile   = aws_iam_instance_profile.minecraft.name
  
  # Prevent accidental termination
  disable_api_termination = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_volume_size
    delete_on_termination = false  # Keep EBS volume even if instance is terminated
  }

  user_data = base64encode(templatefile("${path.module}/../user-data.sh", {
    minecraft_memory = var.minecraft_memory
    auto_shutdown_script = file("${path.module}/../auto-shutdown.sh")
    discord_webhook_url = var.discord_webhook_url
    s3_bucket = "minecraft-server-mods-temp"
  }))

  tags = {
    Name = "minecraft-server"
    AutoShutdown = "true"
  }
  
  # Prevent Terraform from destroying this instance
  lifecycle {
    prevent_destroy = true
  }
}

# Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "instance_public_ip" {
  value       = aws_instance.minecraft.public_ip
  description = "Public IP address of the Minecraft server (dynamic)"
}

output "instance_id" {
  value       = aws_instance.minecraft.id
  description = "EC2 Instance ID"
}

output "api_ready_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/ready"
}
