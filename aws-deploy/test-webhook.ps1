# Test Discord Webhook notification

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Discord Webhook Notification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Checking EC2 instance state..." -ForegroundColor Cyan
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 instance is not running (state: $state)" -ForegroundColor Red
    Write-Host "Start the server first: /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "Success: EC2 instance is running" -ForegroundColor Green
Write-Host ""

Write-Host "2. Creating test script..." -ForegroundColor Cyan

# Create test script file
$testScriptContent = @"
#!/bin/bash
INSTANCE_ID=`$(ec2-metadata --instance-id | cut -d ' ' -f 2)
REGION=`$(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/[a-z]`$//')
echo "Instance ID: `$INSTANCE_ID"
echo "Region: `$REGION"
echo ""
echo "Getting webhook URL from SSM..."
WEBHOOK_URL=`$(aws ssm get-parameter --name "/minecraft/`${INSTANCE_ID}/discord_webhook" --region "`$REGION" --with-decryption --query 'Parameter.Value' --output text 2>&1)
if [ `$? -ne 0 ]; then
    echo "Error getting webhook URL: `$WEBHOOK_URL"
    exit 1
fi
echo "Webhook URL (first 50 chars): `${WEBHOOK_URL:0:50}..."
echo ""
current_time=`$(date '+%Y-%m-%d %H:%M:%S')
json_payload="{\"content\":\"Test notification from auto-shutdown script at `${current_time}\"}"
echo "Sending test notification..."
echo "Payload: `$json_payload"
echo ""
response=`$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "Content-Type: application/json" -X POST -d "`$json_payload" "`$WEBHOOK_URL")
http_code=`$(echo "`$response" | grep "HTTP_CODE:" | cut -d: -f2)
response_body=`$(echo "`$response" | grep -v "HTTP_CODE:")
echo "HTTP Code: `$http_code"
echo "Response: `$response_body"
if [ "`$http_code" = "204" ] || [ "`$http_code" = "200" ]; then
    echo ""
    echo "Success: Notification sent!"
else
    echo ""
    echo "Error: Failed to send notification"
fi
"@

$scriptFile = Join-Path $PSScriptRoot "test-webhook.sh"
[System.IO.File]::WriteAllText($scriptFile, $testScriptContent, [System.Text.Encoding]::UTF8)

Write-Host "3. Uploading and executing test script..." -ForegroundColor Cyan

$commands = @(
    "cat > /tmp/test-webhook.sh << 'EOFSCRIPT'",
    $testScriptContent,
    "EOFSCRIPT",
    "chmod +x /tmp/test-webhook.sh",
    "/tmp/test-webhook.sh"
)

$paramsJson = @{
    commands = $commands
} | ConvertTo-Json -Compress

$paramsFile = Join-Path $PWD "ssm-test-params.json"
[System.IO.File]::WriteAllText($paramsFile, $paramsJson, [System.Text.Encoding]::ASCII)

$commandId = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters "file://$paramsFile" `
    --region $REGION `
    --query 'Command.CommandId' `
    --output text

Remove-Item $paramsFile -ErrorAction SilentlyContinue
Remove-Item $scriptFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to send SSM command" -ForegroundColor Red
    exit 1
}

Write-Host "Success: SSM command sent (CommandId: $commandId)" -ForegroundColor Green
Write-Host ""
Write-Host "4. Waiting for command execution..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "5. Getting execution result..." -ForegroundColor Cyan
$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --query 'StandardOutputContent' `
    --output text

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Result:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host $output

if ($output -match "Success: Notification sent!") {
    Write-Host ""
    Write-Host "Success: Webhook is working correctly!" -ForegroundColor Green
    Write-Host "Check 'server-status' channel for test notification" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Error: Webhook test failed" -ForegroundColor Red
    Write-Host "Check the details above" -ForegroundColor Yellow
}
