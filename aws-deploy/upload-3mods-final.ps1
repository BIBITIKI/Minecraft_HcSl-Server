# 3 MOD files upload script
$instanceId = "i-0b3b312b21a19f71b"
$region = "ap-northeast-1"

$modFiles = @(
    "C:\Kiro\Minecraft_HcSl-Server\mods\kotlinforforge-4.12.0-all.jar",
    "C:\Kiro\Minecraft_HcSl-Server\mods\libIPN-forge-1.20-4.0.2.jar",
    "C:\Kiro\Minecraft_HcSl-Server\mods\InventoryProfilesNext-forge-1.20-1.10.20.jar"
)

Write-Host "=== Upload 3 MOD files ===" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $modFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "Error: File not found: $file" -ForegroundColor Red
        exit 1
    }
    $fileName = Split-Path $file -Leaf
    $sizeMB = [Math]::Round((Get-Item $file).Length / 1MB, 2)
    Write-Host "  OK: $fileName (${sizeMB} MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Checking EC2 instance state..." -ForegroundColor Yellow

$state = aws ec2 describe-instances --instance-ids $instanceId --region $region --query "Reservations[0].Instances[0].State.Name" --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 is not running (state: $state)" -ForegroundColor Red
    exit 1
}

Write-Host "EC2 is running" -ForegroundColor Green
Write-Host ""

$bucketName = "minecraft-mods-temp-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "Creating temp S3 bucket: $bucketName" -ForegroundColor Yellow
aws s3 mb "s3://$bucketName" --region $region

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to create S3 bucket" -ForegroundColor Red
    exit 1
}

Write-Host "S3 bucket created" -ForegroundColor Green
Write-Host ""

try {
    Write-Host "Uploading MOD files to S3..." -ForegroundColor Yellow
    
    foreach ($file in $modFiles) {
        $fileName = Split-Path $file -Leaf
        Write-Host "  Uploading: $fileName" -ForegroundColor Cyan
        aws s3 cp $file "s3://$bucketName/mods/$fileName" --region $region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Done" -ForegroundColor Green
        } else {
            Write-Host "    Failed" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "S3 upload completed" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Downloading MOD files on EC2..." -ForegroundColor Yellow
    
    $commandScript = "cd /home/ubuntu/minecraft; sudo systemctl stop minecraft; mkdir -p mods_backup; mv mods/*.jar mods_backup/ 2>/dev/null; mkdir -p mods; aws s3 sync s3://$bucketName/mods/ mods/ --region $region; sudo chown -R ubuntu:ubuntu mods; sudo systemctl start minecraft; echo MOD_UPDATE_DONE"
    
    $cmdId = aws ssm send-command --instance-ids $instanceId --region $region --document-name AWS-RunShellScript --parameters commands="""$commandScript""" --query Command.CommandId --output text
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to send SSM command" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "SSM command sent (ID: $cmdId)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting for command execution..." -ForegroundColor Yellow
    
    $maxWait = 60
    $waited = 0
    $success = $false
    
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 2
        $waited += 2
        
        $status = aws ssm get-command-invocation --command-id $cmdId --instance-id $instanceId --region $region --query Status --output text 2>$null
        
        if ($status -eq "Success") {
            $success = $true
            break
        } elseif ($status -eq "Failed" -or $status -eq "Cancelled" -or $status -eq "TimedOut") {
            Write-Host "Error: Command execution failed (Status: $status)" -ForegroundColor Red
            
            $errorMsg = aws ssm get-command-invocation --command-id $cmdId --instance-id $instanceId --region $region --query StandardErrorContent --output text 2>$null
            
            if ($errorMsg) {
                Write-Host "Error details: $errorMsg" -ForegroundColor Red
            }
            exit 1
        }
        
        if ($waited % 10 -eq 0) {
            Write-Host "  Waiting... ($waited/$maxWait sec)" -ForegroundColor Gray
        }
    }
    
    if ($success) {
        Write-Host ""
        Write-Host "SUCCESS: MOD files uploaded!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Uploaded MODs:" -ForegroundColor Cyan
        Write-Host "  - kotlinforforge-4.12.0-all.jar" -ForegroundColor Green
        Write-Host "  - libIPN-forge-1.20-4.0.2.jar" -ForegroundColor Green
        Write-Host "  - InventoryProfilesNext-forge-1.20-1.10.20.jar" -ForegroundColor Green
        Write-Host ""
        Write-Host "Minecraft server restarted" -ForegroundColor Yellow
        Write-Host "Wait 2-3 minutes before connecting" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Timeout: Command execution not completed" -ForegroundColor Red
        Write-Host "Please check manually" -ForegroundColor Yellow
    }
    
} finally {
    Write-Host ""
    Write-Host "Deleting temp S3 bucket..." -ForegroundColor Yellow
    aws s3 rb "s3://$bucketName" --force --region $region 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 bucket deleted" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to delete S3 bucket (delete manually)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Process completed" -ForegroundColor Cyan
