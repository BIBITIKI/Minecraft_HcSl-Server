# Regenerate Minecraft world on EC2

$KeyFile = "C:\Kiro\minecraft-server-key.pem"
$InstanceId = "i-0e71ec8304bf61354"
$Region = "ap-northeast-1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Minecraft World Regeneration" -ForegroundColor Cyan
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
Write-Host "WARNING: This will DELETE the current world and generate a new one!" -ForegroundColor Red
Write-Host "The old world will be backed up to S3." -ForegroundColor Yellow
Write-Host ""
$Confirm = Read-Host "Are you sure you want to continue? (yes/no)"

if ($Confirm -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Uploading regeneration script..." -ForegroundColor Yellow
scp -i $KeyFile Minecraft_HcSl-Server/aws-deploy/regenerate-world.sh ec2-user@${IpAddress}:/tmp/

Write-Host "Executing regeneration script..." -ForegroundColor Yellow
ssh -i $KeyFile ec2-user@$IpAddress "chmod +x /tmp/regenerate-world.sh && sudo /tmp/regenerate-world.sh"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "World regeneration completed!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To check server logs:" -ForegroundColor Yellow
Write-Host "ssh -i $KeyFile ec2-user@$IpAddress 'sudo journalctl -u minecraft.service -f'" -ForegroundColor White
Write-Host ""
Write-Host "To check world generation progress:" -ForegroundColor Yellow
Write-Host "ssh -i $KeyFile ec2-user@$IpAddress 'sudo tail -f /home/ec2-user/minecraft/logs/latest.log'" -ForegroundColor White
