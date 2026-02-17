# Check auto-shutdown log

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "Checking auto-shutdown log..." -ForegroundColor Cyan

$commandId = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters 'commands=["tail -100 /var/log/minecraft-autoshutdown.log"]' `
    --region $REGION `
    --query 'Command.CommandId' `
    --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to send SSM command" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 3

$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --query 'StandardOutputContent' `
    --output text

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Auto-Shutdown Log (last 100 lines):" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host $output
