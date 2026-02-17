# Auto-shutdown script update - Fixed version
$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"
$SCRIPT_PATH = "./auto-shutdown.sh"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto-shutdown script update" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check EC2 state
Write-Host "[1/4] Checking EC2 instance state..." -ForegroundColor Yellow
$state = aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text

if ($state -ne "running") {
    Write-Host "Error: EC2 instance is not running (state: $state)" -ForegroundColor Red
    Write-Host "Please start the server first: /start" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: EC2 instance is running" -ForegroundColor Green
Write-Host ""

# 2. Check SSM Parameter Store
Write-Host "[2/4] Checking SSM Parameter Store..." -ForegroundColor Yellow
$idleTime = aws ssm get-parameter --name "/minecraft/$INSTANCE_ID/idle_time" --region $REGION --query 'Parameter.Value' --output text 2>$null

if ($idleTime) {
    $minutes = [math]::Floor($idleTime / 60)
    Write-Host "OK: Current setting: $minutes minutes ($idleTime seconds)" -ForegroundColor Green
} else {
    Write-Host "Warning: No setting found (default: 15 minutes)" -ForegroundColor Yellow
}
Write-Host ""

# 3. Upload script
Write-Host "[3/4] Uploading script to EC2..." -ForegroundColor Yellow

$scriptContent = Get-Content $SCRIPT_PATH -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($scriptContent)
$base64 = [Convert]::ToBase64String($bytes)

# Create temporary JSON file for parameters
$commandJson = @{
    commands = @(
        "echo `"$base64`" | base64 -d > /tmp/auto-shutdown-new.sh",
        "chmod +x /tmp/auto-shutdown-new.sh",
        "sudo cp /tmp/auto-shutdown-new.sh /usr/local/bin/auto-shutdown.sh",
        "sudo cp /tmp/auto-shutdown-new.sh /usr/local/bin/minecraft-autoshutdown.sh",
        "echo Script uploaded successfully"
    )
} | ConvertTo-Json -Compress

$tempFile = New-TemporaryFile
[System.IO.File]::WriteAllText($tempFile.FullName, $commandJson, [System.Text.UTF8Encoding]::new($false))

try {
    $result = aws ssm send-command `
        --instance-ids $INSTANCE_ID `
        --region $REGION `
        --document-name "AWS-RunShellScript" `
        --parameters file://$($tempFile.FullName) `
        --output json | ConvertFrom-Json

    $commandId = $result.Command.CommandId
    Write-Host "Command ID: $commandId" -ForegroundColor Cyan

    Start-Sleep -Seconds 5

    for ($i = 0; $i -lt 10; $i++) {
        $commandResult = aws ssm get-command-invocation `
            --command-id $commandId `
            --instance-id $INSTANCE_ID `
            --region $REGION `
            --output json 2>$null | ConvertFrom-Json
        
        if ($commandResult.Status -eq "Success") {
            Write-Host "OK: Script upload completed" -ForegroundColor Green
            break
        } elseif ($commandResult.Status -eq "Failed") {
            Write-Host "Error: Script upload failed" -ForegroundColor Red
            Write-Host $commandResult.StandardErrorContent
            exit 1
        }
        
        Start-Sleep -Seconds 2
    }
} finally {
    Remove-Item $tempFile.FullName -ErrorAction SilentlyContinue
}

Write-Host ""

# 4. Restart service
Write-Host "[4/4] Restarting auto-shutdown service..." -ForegroundColor Yellow

$restartJson = @{
    commands = @(
        "sudo systemctl restart minecraft-autoshutdown.service",
        "echo Service restarted",
        "sudo systemctl status minecraft-autoshutdown.service --no-pager"
    )
} | ConvertTo-Json -Compress

$tempFile2 = New-TemporaryFile
[System.IO.File]::WriteAllText($tempFile2.FullName, $restartJson, [System.Text.UTF8Encoding]::new($false))

try {
    $result2 = aws ssm send-command `
        --instance-ids $INSTANCE_ID `
        --region $REGION `
        --document-name "AWS-RunShellScript" `
        --parameters file://$($tempFile2.FullName) `
        --output json | ConvertFrom-Json

    $commandId2 = $result2.Command.CommandId
    Start-Sleep -Seconds 3

    $commandResult2 = aws ssm get-command-invocation `
        --command-id $commandId2 `
        --instance-id $INSTANCE_ID `
        --region $REGION `
        --output json 2>$null | ConvertFrom-Json

    if ($commandResult2.Status -eq "Success") {
        Write-Host "OK: Service restart completed" -ForegroundColor Green
    } else {
        Write-Host "Warning: Service restart may have failed" -ForegroundColor Yellow
    }
} finally {
    Remove-Item $tempFile2.FullName -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Update completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($idleTime) {
    $minutes = [math]::Floor($idleTime / 60)
    Write-Host "Current auto-shutdown setting: $minutes minutes" -ForegroundColor Green
    Write-Host "Setting will be applied within 1 minute" -ForegroundColor Green
}

Write-Host ""
Write-Host "To check logs: sudo tail -f /var/log/minecraft-autoshutdown.log" -ForegroundColor Cyan
