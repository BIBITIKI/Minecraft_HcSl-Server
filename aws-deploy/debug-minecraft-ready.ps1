# Debug script to check Minecraft ready status

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Debug Minecraft Ready Check" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Checking EC2 state..." -ForegroundColor Cyan
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 is not running (state: $state)" -ForegroundColor Red
    Write-Host "Start the server first with /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "EC2 is running" -ForegroundColor Green
Write-Host ""

Write-Host "2. Checking Minecraft log file..." -ForegroundColor Cyan
$commandId = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters 'commands=["echo \"=== Checking log file ===\"","ls -la /minecraft/server/logs/","echo \"\"","echo \"=== Checking for Done message ===\"","if [ -f /minecraft/server/logs/latest.log ]; then grep \"Done (\" /minecraft/server/logs/latest.log | tail -n 5; else echo \"Log file not found\"; fi","echo \"\"","echo \"=== Last 20 lines of log ===\"","if [ -f /minecraft/server/logs/latest.log ]; then tail -n 20 /minecraft/server/logs/latest.log; else echo \"Log file not found\"; fi"]' `
    --region $REGION `
    --query 'Command.CommandId' `
    --output text

Write-Host "Command ID: $commandId" -ForegroundColor Gray
Write-Host "Waiting for command execution..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "3. Getting command output..." -ForegroundColor Cyan
$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --query 'StandardOutputContent' `
    --output text

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Command Output:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host $output

Write-Host ""
Write-Host "4. Testing Lambda function..." -ForegroundColor Cyan
aws lambda invoke --function-name minecraft-check-ready --region $REGION response.json | Out-Null
$lambdaResponse = Get-Content response.json | ConvertFrom-Json

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Lambda Response:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
$lambdaResponse.body | ConvertFrom-Json | ConvertTo-Json -Depth 10

Remove-Item response.json -ErrorAction SilentlyContinue
