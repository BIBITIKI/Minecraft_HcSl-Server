# EC2からMinecraftサーバーファイルをダウンロード

$INSTANCE_ID = "i-0b3b312b21a19f71b"
$REGION = "ap-northeast-1"
$LOCAL_DIR = "server-files"

Write-Host "Downloading Minecraft server files..." -ForegroundColor Green

# Download main config files
$files = @(
    "/home/ubuntu/minecraft/server.properties",
    "/home/ubuntu/minecraft/eula.txt",
    "/home/ubuntu/minecraft/ops.json",
    "/home/ubuntu/minecraft/whitelist.json",
    "/home/ubuntu/minecraft/banned-players.json",
    "/home/ubuntu/minecraft/banned-ips.json"
)

foreach ($file in $files) {
    $filename = Split-Path $file -Leaf
    Write-Host "Downloading: $filename"
    
    $command = "cat $file"
    $result = aws ssm send-command `
        --instance-ids $INSTANCE_ID `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['$command']" `
        --region $REGION `
        --output json | ConvertFrom-Json
    
    $commandId = $result.Command.CommandId
    
    # Wait for command completion
    Start-Sleep -Seconds 2
    
    $output = aws ssm get-command-invocation `
        --command-id $commandId `
        --instance-id $INSTANCE_ID `
        --region $REGION `
        --output json | ConvertFrom-Json
    
    if ($output.Status -eq "Success") {
        $content = $output.StandardOutputContent
        $localPath = Join-Path $LOCAL_DIR $filename
        $content | Out-File -FilePath $localPath -Encoding UTF8
        Write-Host "  Saved: $localPath" -ForegroundColor Green
    } else {
        Write-Host "  Failed: $filename" -ForegroundColor Red
    }
}

# Download config folder (compressed)
Write-Host ""
Write-Host "Downloading config folder..."
$command = "cd /home/ubuntu/minecraft && tar -czf /tmp/config.tar.gz config 2>/dev/null && base64 /tmp/config.tar.gz"
$result = aws ssm send-command `
    --instance-ids $INSTANCE_ID `
    --document-name "AWS-RunShellScript" `
    --parameters "commands=['$command']" `
    --region $REGION `
    --output json | ConvertFrom-Json

$commandId = $result.Command.CommandId
Start-Sleep -Seconds 3

$output = aws ssm get-command-invocation `
    --command-id $commandId `
    --instance-id $INSTANCE_ID `
    --region $REGION `
    --output json | ConvertFrom-Json

if ($output.Status -eq "Success" -and $output.StandardOutputContent) {
    $base64Content = $output.StandardOutputContent
    $bytes = [System.Convert]::FromBase64String($base64Content)
    $tarPath = Join-Path $LOCAL_DIR "config.tar.gz"
    [System.IO.File]::WriteAllBytes($tarPath, $bytes)
    
    # Extract
    tar -xzf $tarPath -C $LOCAL_DIR
    Remove-Item $tarPath
    Write-Host "  Config folder extracted" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Files saved to $LOCAL_DIR folder." -ForegroundColor Green
