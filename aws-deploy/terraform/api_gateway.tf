# API Gateway REST API
resource "aws_api_gateway_rest_api" "minecraft" {
  name        = "minecraft-server-api"
  description = "API for Minecraft server control"
}

# /start リソース
resource "aws_api_gateway_resource" "start" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "start"
}

# /stop リソース
resource "aws_api_gateway_resource" "stop" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "stop"
}

# /status リソース
resource "aws_api_gateway_resource" "status" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "status"
}

# /logs リソース
resource "aws_api_gateway_resource" "logs" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "logs"
}

# /config リソース
resource "aws_api_gateway_resource" "config" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "config"
}

# /notify リソース
resource "aws_api_gateway_resource" "notify" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "notify"
}

# GET /start メソッド
resource "aws_api_gateway_method" "start_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.start.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /stop メソッド
resource "aws_api_gateway_method" "stop_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.stop.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /status メソッド
resource "aws_api_gateway_method" "status_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.status.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /logs メソッド
resource "aws_api_gateway_method" "logs_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.logs.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /config メソッド
resource "aws_api_gateway_method" "config_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.config.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /notify メソッド
resource "aws_api_gateway_method" "notify_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.notify.id
  http_method   = "GET"
  authorization = "NONE"
}

# Lambda統合 - start
resource "aws_api_gateway_integration" "start_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.start.id
  http_method             = aws_api_gateway_method.start_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.start_minecraft.invoke_arn
}

# Lambda統合 - stop
resource "aws_api_gateway_integration" "stop_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.stop.id
  http_method             = aws_api_gateway_method.stop_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.stop_minecraft.invoke_arn
}

# Lambda統合 - status
resource "aws_api_gateway_integration" "status_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.status.id
  http_method             = aws_api_gateway_method.status_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.status_minecraft.invoke_arn
}

# Lambda統合 - logs
resource "aws_api_gateway_integration" "logs_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.logs.id
  http_method             = aws_api_gateway_method.logs_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_logs_minecraft.invoke_arn
}

# Lambda統合 - config
resource "aws_api_gateway_integration" "config_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.config.id
  http_method             = aws_api_gateway_method.config_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_config_minecraft.invoke_arn
}

# Lambda統合 - notify
resource "aws_api_gateway_integration" "notify_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft.id
  resource_id             = aws_api_gateway_resource.notify.id
  http_method             = aws_api_gateway_method.notify_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notify_discord.invoke_arn
}

# Lambda権限 - API Gateway
resource "aws_lambda_permission" "apigw_start" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_minecraft.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_stop" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_minecraft.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_status" {
  statement_id  = "AllowAPIGatewayInvokeStatus"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.status_minecraft.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_logs" {
  statement_id  = "AllowAPIGatewayInvokeLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_logs_minecraft.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_config" {
  statement_id  = "AllowAPIGatewayInvokeConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_config_minecraft.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_notify" {
  statement_id  = "AllowAPIGatewayInvokeNotify"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_discord.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}

# デプロイメント
resource "aws_api_gateway_deployment" "minecraft" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.start.id,
      aws_api_gateway_method.start_get.id,
      aws_api_gateway_integration.start_lambda.id,
      aws_api_gateway_resource.stop.id,
      aws_api_gateway_method.stop_get.id,
      aws_api_gateway_integration.stop_lambda.id,
      aws_api_gateway_resource.status.id,
      aws_api_gateway_method.status_get.id,
      aws_api_gateway_integration.status_lambda.id,
      aws_api_gateway_resource.logs.id,
      aws_api_gateway_method.logs_get.id,
      aws_api_gateway_integration.logs_lambda.id,
      aws_api_gateway_resource.config.id,
      aws_api_gateway_method.config_get.id,
      aws_api_gateway_integration.config_lambda.id,
      aws_api_gateway_resource.notify.id,
      aws_api_gateway_method.notify_get.id,
      aws_api_gateway_integration.notify_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.start_lambda,
    aws_api_gateway_integration.stop_lambda,
    aws_api_gateway_integration.status_lambda,
    aws_api_gateway_integration.logs_lambda,
    aws_api_gateway_integration.config_lambda,
    aws_api_gateway_integration.notify_lambda
  ]
}

# ステージ
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.minecraft.id
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  stage_name    = "prod"
}

# 出力
output "api_start_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/start"
  description = "API Gateway URL for starting server"
}

output "api_stop_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/stop"
  description = "API Gateway URL for stopping server"
}

output "api_status_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/status"
  description = "API Gateway URL for checking server status"
}

output "api_logs_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/logs"
  description = "API Gateway URL for getting server logs"
}

output "api_config_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/config"
  description = "API Gateway URL for updating server config"
}

output "api_notify_url" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/notify"
  description = "API Gateway URL for sending Discord notifications"
}

# API Gateway: /ready エンドポイント
resource "aws_api_gateway_resource" "ready" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  parent_id   = aws_api_gateway_rest_api.minecraft.root_resource_id
  path_part   = "ready"
}

resource "aws_api_gateway_method" "ready_get" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft.id
  resource_id   = aws_api_gateway_resource.ready.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "ready_lambda" {
  rest_api_id = aws_api_gateway_rest_api.minecraft.id
  resource_id = aws_api_gateway_resource.ready.id
  http_method = aws_api_gateway_method.ready_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.check_minecraft_ready.invoke_arn
}

resource "aws_lambda_permission" "apigw_ready" {
  statement_id  = "AllowAPIGatewayInvokeReady"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_minecraft_ready.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.minecraft.execution_arn}/*/*"
}
