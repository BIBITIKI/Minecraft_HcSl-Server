# Update auto-shutdown script on running EC2 instance via SSM

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "Updating auto-shutdown script on EC2 instance: $INSTANCE_ID" -ForegroundColor Cyan

# Read the new auto-shutdown script
$scriptContent = Get-Content -Path "auto-shutdown.sh" -Raw

# Escape single quotes for bash
$scriptContent = $scriptContent -replace "'", "'\\''"

# Create SSM command to update the script
$command = @"
#!/bin/bash
set -e

echo "Stopping minecraft-autoshutdown service..."
systemctl stop minecraft-autoshutdown.service

echo "Backing up old script..."
cp /usr/local/bin/minecraft-autoshutdown.sh /usr/local/bin/minecraft-autoshutdown.sh.backup

echo "Writing new script..."
cat > /usr/local/bin/minecraft-autoshutdown.sh << 'AUTOSHUTDOWN_EOF'
$scriptContent
AUTOSHUTDOWN_EOF

echo "Setting permissions..."
chmod +x /usr/local/bin/minecraft-autoshutdown.sh

echo "Restarting minecraft-autoshutdown service..."
systemctl start minecraft-autoshutdown.service

echo "Checking service status..."
systemctl status minecraft-autoshutdown.service --no-pager

echo "Tailing log (last 20 lines)..."
tail -n 20 /var/log/minecraft-autoshutdown.log

echo "Script update completed successfully!"
"@

# Save command to temporary file
$command | Out-File -FilePath "temp-update-command.sh" -Encoding UTF8 -NoNewline

Write-Host "Sending SSM command to EC2 instance..." -ForegroundColor Yellow

# Send command via SSM
$result = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=[$command]" `
    --output json | ConvertFrom-Json

$commandId = $result.Command.CommandId

Write-Host "Command sent! Command ID: $commandId" -ForegroundColor Green
Write-Host "Waiting for command to complete..." -ForegroundColor Yellow

# Wait for command to complete
Start-Sleep -Seconds 5

# Get command output
Write-Host "`nFetching command output..." -ForegroundColor Yellow
aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --output text `
    --query 'StandardOutputContent'

Write-Host "`n=== Update Complete ===" -ForegroundColor Green
Write-Host "The auto-shutdown script has been updated on the EC2 instance." -ForegroundColor Green
Write-Host "New features:" -ForegroundColor Cyan
Write-Host "  - Reads IDLE_TIME from SSM Parameter Store" -ForegroundColor White
Write-Host "  - Sends notifications to server-status channel via Discord Bot" -ForegroundColor White
Write-Host "  - Logs instance ID and region for debugging" -ForegroundColor White

# Clean up
Remove-Item "temp-update-command.sh" -ErrorAction SilentlyContinue
