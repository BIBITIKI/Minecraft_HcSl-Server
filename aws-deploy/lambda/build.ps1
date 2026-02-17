# Lambda関数のZIPファイル作成スクリプト

Write-Host "=== Lambda関数のビルド ===" -ForegroundColor Green

$currentDir = Get-Location

# start_server.zip作成
Write-Host "start_server.zip を作成中..." -ForegroundColor Cyan
Compress-Archive -Path "$currentDir\start_server.py" -DestinationPath "$currentDir\start_server.zip" -Force
Rename-Item -Path "$currentDir\start_server.zip" -NewName "start_server_temp.zip" -Force
New-Item -ItemType Directory -Path "$currentDir\temp_start" -Force | Out-Null
Expand-Archive -Path "$currentDir\start_server_temp.zip" -DestinationPath "$currentDir\temp_start" -Force
Rename-Item -Path "$currentDir\temp_start\start_server.py" -NewName "index.py" -Force
Compress-Archive -Path "$currentDir\temp_start\index.py" -DestinationPath "$currentDir\start_server.zip" -Force
Remove-Item -Path "$currentDir\temp_start" -Recurse -Force
Remove-Item -Path "$currentDir\start_server_temp.zip" -Force

# stop_server.zip作成
Write-Host "stop_server.zip を作成中..." -ForegroundColor Cyan
Compress-Archive -Path "$currentDir\stop_server.py" -DestinationPath "$currentDir\stop_server.zip" -Force
Rename-Item -Path "$currentDir\stop_server.zip" -NewName "stop_server_temp.zip" -Force
New-Item -ItemType Directory -Path "$currentDir\temp_stop" -Force | Out-Null
Expand-Archive -Path "$currentDir\stop_server_temp.zip" -DestinationPath "$currentDir\temp_stop" -Force
Rename-Item -Path "$currentDir\temp_stop\stop_server.py" -NewName "index.py" -Force
Compress-Archive -Path "$currentDir\temp_stop\index.py" -DestinationPath "$currentDir\stop_server.zip" -Force
Remove-Item -Path "$currentDir\temp_stop" -Recurse -Force
Remove-Item -Path "$currentDir\stop_server_temp.zip" -Force

Write-Host ""
Write-Host "=== ビルド完了 ===" -ForegroundColor Green
Write-Host "作成されたファイル:" -ForegroundColor Cyan
Write-Host "  - start_server.zip"
Write-Host "  - stop_server.zip"
Write-Host ""
