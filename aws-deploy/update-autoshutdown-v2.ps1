# Update auto-shutdown script on running EC2 instance via SSM
# This script sends the new auto-shutdown.sh content to the EC2 instance

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=== Updating auto-shutdown script on EC2 instance ===" -ForegroundColor Cyan
Write-Host "Instance ID: $INSTANCE_ID" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Read the new auto-shutdown script
$newScript = Get-Content -Path "auto-shutdown.sh" -Raw

# Create a base64 encoded version to avoid escaping issues
$bytes = [System.Text.Encoding]::UTF8.GetBytes($newScript)
$base64Script = [Convert]::ToBase64String($bytes)

# Create the SSM command
$ssmCommand = @"
#!/bin/bash
set -e

echo '=== Updating auto-shutdown script ==='

# Stop the service
echo 'Stopping minecraft-autoshutdown service...'
systemctl stop minecraft-autoshutdown.service

# Backup old script
echo 'Backing up old script...'
cp /usr/local/bin/minecraft-autoshutdown.sh /usr/local/bin/minecraft-autoshutdown.sh.backup.\$(date +%Y%m%d-%H%M%S)

# Decode and write new script
echo 'Writing new script...'
echo '$base64Script' | base64 -d > /usr/local/bin/minecraft-autoshutdown.sh

# Set permissions
echo 'Setting permissions...'
chmod +x /usr/local/bin/minecraft-autoshutdown.sh

# Restart service
echo 'Restarting minecraft-autoshutdown service...'
systemctl start minecraft-autoshutdown.service

# Check status
echo ''
echo '=== Service Status ==='
systemctl status minecraft-autoshutdown.service --no-pager || true

# Show recent logs
echo ''
echo '=== Recent Logs (last 30 lines) ==='
tail -n 30 /var/log/minecraft-autoshutdown.log || echo 'Log file not found yet'

echo ''
echo '=== Update Complete ==='
echo 'New features:'
echo '  - Reads IDLE_TIME from SSM Parameter Store'
echo '  - Sends notifications to server-status channel via Discord Bot'
echo '  - Improved logging with instance ID and region'
"@

# Save command to file for debugging
$ssmCommand | Out-File -FilePath "temp-ssm-command.sh" -Encoding UTF8

Write-Host "Sending SSM command..." -ForegroundColor Yellow

# Send command via AWS CLI
$commandJson = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --region $REGION `
    --document-name "AWS-RunShellScript" `
    --comment "Update auto-shutdown script to new version with SSM + Discord Bot support" `
    --parameters "commands=[$ssmCommand]" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to send SSM command!" -ForegroundColor Red
    exit 1
}

$result = $commandJson | ConvertFrom-Json
$commandId = $result.Command.CommandId

Write-Host "Command sent successfully!" -ForegroundColor Green
Write-Host "Command ID: $commandId" -ForegroundColor Cyan
Write-Host ""
Write-Host "Waiting 10 seconds for command to execute..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get command output
Write-Host ""
Write-Host "=== Command Output ===" -ForegroundColor Cyan
$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --output json | ConvertFrom-Json

Write-Host $output.StandardOutputContent -ForegroundColor White

if ($output.StandardErrorContent) {
    Write-Host ""
    Write-Host "=== Errors ===" -ForegroundColor Red
    Write-Host $output.StandardErrorContent -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Update Complete ===" -ForegroundColor Green
Write-Host "The auto-shutdown script has been updated on the EC2 instance." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. The service should now be running with the new script" -ForegroundColor White
Write-Host "  2. Check logs: tail -f /var/log/minecraft-autoshutdown.log" -ForegroundColor White
Write-Host "  3. Verify IDLE_TIME is read from SSM Parameter Store" -ForegroundColor White
Write-Host "  4. Test auto-shutdown notification goes to server-status channel" -ForegroundColor White

# Clean up
Remove-Item "temp-ssm-command.sh" -ErrorAction SilentlyContinue
