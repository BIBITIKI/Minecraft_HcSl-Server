# Configure Minecraft server and regenerate world

$KeyFile = "C:\Kiro\minecraft-server-key.pem"
$InstanceId = "i-0e71ec8304bf61354"
$Region = "ap-northeast-1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Minecraft Server Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Get instance IP
Write-Host "Getting instance IP..." -ForegroundColor Yellow
$IpAddress = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].PublicIpAddress" --output text

if ($IpAddress -eq "None" -or [string]::IsNullOrEmpty($IpAddress)) {
    Write-Host "Instance is not running. Starting instance..." -ForegroundColor Yellow
    aws ec2 start-instances --instance-ids $InstanceId --region $Region | Out-Null
    Write-Host "Waiting for instance to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    $IpAddress = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].PublicIpAddress" --output text
}

Write-Host "Instance IP: $IpAddress" -ForegroundColor Green
Write-Host ""

# Confirm action
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Regenerate world (old world backed up)" -ForegroundColor White
Write-Host "  2. Set difficulty to HARD" -ForegroundColor White
Write-Host "  3. Enable command blocks" -ForegroundColor White
Write-Host "  4. Grant BIBITIKI operator permissions (level 4)" -ForegroundColor White
Write-Host ""
$Confirm = Read-Host "Continue? (yes/no)"

if ($Confirm -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Uploading configuration script..." -ForegroundColor Yellow
scp -i $KeyFile configure-server.sh ec2-user@${IpAddress}:/tmp/

Write-Host "Executing configuration script..." -ForegroundColor Yellow
ssh -i $KeyFile ec2-user@$IpAddress "chmod +x /tmp/configure-server.sh && sudo /tmp/configure-server.sh"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuration completed!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server is generating new world..." -ForegroundColor Yellow
Write-Host "This will take 1-2 minutes." -ForegroundColor Yellow
Write-Host ""
Write-Host "To check progress:" -ForegroundColor Yellow
Write-Host "ssh -i $KeyFile ec2-user@$IpAddress 'sudo tail -f /home/ec2-user/minecraft/logs/latest.log'" -ForegroundColor White
