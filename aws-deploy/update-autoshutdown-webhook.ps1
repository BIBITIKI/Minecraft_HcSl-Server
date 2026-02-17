# Upload auto-shutdown.sh (Webhook version) to EC2 and restart service

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"
$SCRIPT_PATH = Join-Path $PSScriptRoot "auto-shutdown.sh"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deploy auto-shutdown.sh (Webhook version)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if file exists
if (-not (Test-Path $SCRIPT_PATH)) {
    Write-Host "Error: $SCRIPT_PATH not found" -ForegroundColor Red
    exit 1
}

Write-Host "1. Checking EC2 instance state..." -ForegroundColor Cyan
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 instance is not running (state: $state)" -ForegroundColor Red
    Write-Host "Start the server first: /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "Success: EC2 instance is running" -ForegroundColor Green
Write-Host ""

Write-Host "2. Uploading script via SSM..." -ForegroundColor Cyan

# Read script content as string
$scriptContent = [System.IO.File]::ReadAllText($SCRIPT_PATH, [System.Text.Encoding]::UTF8)

# Create SSM document parameters JSON
$commands = @(
    "cat > /tmp/auto-shutdown.sh << 'EOFSCRIPT'",
    $scriptContent,
    "EOFSCRIPT",
    "sudo mv /tmp/auto-shutdown.sh /usr/local/bin/auto-shutdown.sh",
    "sudo chmod +x /usr/local/bin/auto-shutdown.sh",
    "sudo systemctl restart minecraft-autoshutdown.service",
    "sleep 2",
    "sudo systemctl status minecraft-autoshutdown.service --no-pager"
)

# Create JSON file for parameters
$paramsJson = @{
    commands = $commands
} | ConvertTo-Json -Compress

$paramsFile = Join-Path $PWD "ssm-params.json"
# Use ASCII encoding to avoid BOM issues
[System.IO.File]::WriteAllText($paramsFile, $paramsJson, [System.Text.Encoding]::ASCII)

Write-Host "Debug: JSON file created at $paramsFile" -ForegroundColor Gray

# Send command
$commandId = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters "file://$paramsFile" `
    --region $REGION `
    --query 'Command.CommandId' `
    --output text

if (Test-Path $paramsFile) {
    Remove-Item $paramsFile
}

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commandId)) {
    Write-Host "Error: Failed to send SSM command" -ForegroundColor Red
    exit 1
}

Write-Host "Success: SSM command sent (CommandId: $commandId)" -ForegroundColor Green
Write-Host ""
Write-Host "3. Waiting for command execution..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "4. Getting execution result..." -ForegroundColor Cyan
$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --query 'StandardOutputContent' `
    --output text

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Execution Result:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host $output

if ($output -match "Active: active \(running\)") {
    Write-Host ""
    Write-Host "Success: Service started successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Wait 2 minutes with no players"
    Write-Host "2. Check if auto-shutdown notification appears in 'server-status' channel"
} else {
    Write-Host ""
    Write-Host "Error: Service failed to start" -ForegroundColor Red
    Write-Host "Check the details above" -ForegroundColor Yellow
}
