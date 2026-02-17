# Lambda実行ロール
resource "aws_iam_role" "lambda_minecraft" {
  name = "minecraft-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda用ポリシー
resource "aws_iam_role_policy" "lambda_minecraft_policy" {
  name = "minecraft-lambda-policy"
  role = aws_iam_role.lambda_minecraft.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda関数: サーバー起動
resource "aws_lambda_function" "start_minecraft" {
  filename      = "${path.module}/../lambda/start_server.zip"
  function_name = "minecraft-start-server"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "start_server.lambda_handler"
  runtime       = "python3.11"
  timeout       = 600
  source_code_hash = filebase64sha256("${path.module}/../lambda/start_server.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
      WEBHOOK_URL = var.discord_webhook_url
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: サーバー停止
resource "aws_lambda_function" "stop_minecraft" {
  filename      = "${path.module}/../lambda/stop_server.zip"
  function_name = "minecraft-stop-server"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "stop_server.lambda_handler"
  runtime       = "python3.11"
  timeout       = 360
  source_code_hash = filebase64sha256("${path.module}/../lambda/stop_server.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
      WEBHOOK_URL = var.discord_webhook_url
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: サーバーステータス確認
resource "aws_lambda_function" "status_minecraft" {
  filename      = "${path.module}/../lambda/status_server.zip"
  function_name = "minecraft-status-server"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "status_server.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  source_code_hash = filebase64sha256("${path.module}/../lambda/status_server.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数URL（Discord Botから呼び出し用）
resource "aws_lambda_function_url" "start_minecraft" {
  function_name      = aws_lambda_function.start_minecraft.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    max_age       = 86400
  }
}

resource "aws_lambda_function_url" "stop_minecraft" {
  function_name      = aws_lambda_function.stop_minecraft.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    max_age       = 86400
  }
}

resource "aws_lambda_function_url" "status_minecraft" {
  function_name      = aws_lambda_function.status_minecraft.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    max_age       = 86400
  }
}

# Lambda Function URL用の権限
resource "aws_lambda_permission" "allow_function_url_start" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.start_minecraft.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "allow_function_url_stop" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.stop_minecraft.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "allow_function_url_status" {
  statement_id           = "FunctionURLAllowPublicAccessStatus"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.status_minecraft.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# EventBridge: 深夜3時に自動停止
resource "aws_cloudwatch_event_rule" "stop_at_3am" {
  name                = "minecraft-stop-at-3am"
  description         = "Stop Minecraft server at 3:00 AM JST"
  schedule_expression = "cron(0 18 * * ? *)"  # UTC 18:00 = JST 3:00
}

resource "aws_cloudwatch_event_target" "stop_at_3am" {
  rule      = aws_cloudwatch_event_rule.stop_at_3am.name
  target_id = "StopMinecraftInstance"
  arn       = aws_lambda_function.stop_minecraft.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_minecraft.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_at_3am.arn
}

# 出力
output "lambda_start_url" {
  value       = aws_lambda_function_url.start_minecraft.function_url
  description = "Lambda function URL for starting server (use in Discord Bot)"
}

output "lambda_stop_url" {
  value       = aws_lambda_function_url.stop_minecraft.function_url
  description = "Lambda function URL for stopping server (use in Discord Bot)"
}

output "lambda_status_url" {
  value       = aws_lambda_function_url.status_minecraft.function_url
  description = "Lambda function URL for checking server status (use in Discord Bot)"
}

# Lambda関数: ログ取得
resource "aws_lambda_function" "get_logs_minecraft" {
  filename      = "${path.module}/../lambda/get_logs.zip"
  function_name = "minecraft-get-logs"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "get_logs.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  source_code_hash = filebase64sha256("${path.module}/../lambda/get_logs.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: 設定更新
resource "aws_lambda_function" "update_config_minecraft" {
  filename      = "${path.module}/../lambda/update_config.zip"
  function_name = "minecraft-update-config"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "update_config.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  source_code_hash = filebase64sha256("${path.module}/../lambda/update_config.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: Discord通知送信
resource "aws_lambda_function" "send_notification_minecraft" {
  filename      = "${path.module}/../lambda/send_notification.zip"
  function_name = "minecraft-send-notification"
  role          = aws_iam_role.lambda_minecraft.arn
  handler       = "send_notification.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  source_code_hash = filebase64sha256("${path.module}/../lambda/send_notification.zip")

  environment {
    variables = {
      INSTANCE_ID      = aws_instance.minecraft.id
      DISCORD_BOT_URL  = var.discord_bot_url
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: Minecraft起動状態チェック
resource "aws_lambda_function" "check_minecraft_ready" {
  filename         = "${path.module}/../lambda/check_minecraft_ready.zip"
  function_name    = "minecraft-check-ready"
  role            = aws_iam_role.lambda_minecraft.arn
  handler         = "check_minecraft_ready.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  source_code_hash = filebase64sha256("${path.module}/../lambda/check_minecraft_ready.zip")

  environment {
    variables = {
      INSTANCE_ID = aws_instance.minecraft.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}

# Lambda関数: Discord通知
resource "aws_lambda_function" "notify_discord" {
  filename         = "${path.module}/../lambda/notify_discord.zip"
  function_name    = "minecraft-notify-discord"
  role            = aws_iam_role.lambda_minecraft.arn
  handler         = "notify_discord.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  source_code_hash = filebase64sha256("${path.module}/../lambda/notify_discord.zip")

  environment {
    variables = {
      DISCORD_BOT_URL = var.discord_bot_url
    }
  }

  depends_on = [aws_iam_role_policy.lambda_minecraft_policy]
}
