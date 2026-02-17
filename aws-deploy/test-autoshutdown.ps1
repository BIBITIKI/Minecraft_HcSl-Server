# 自動停止スクリプトのテスト用（PowerShell版）

param(
    [string]$LogFile = "logs\latest.log"
)

if (-not (Test-Path $LogFile)) {
    Write-Host "エラー: ログファイルが見つかりません: $LogFile" -ForegroundColor Red
    exit 1
}

Write-Host "=========================================" -ForegroundColor Green
Write-Host "自動停止スクリプト テスト"
Write-Host "ログファイル: $LogFile"
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

$players = @{}

Get-Content $LogFile | ForEach-Object {
    if ($_ -match '\]:\s+(\S+)\s+joined\s+the\s+game') {
        $player = $Matches[1]
        $players[$player] = $true
        Write-Host "[JOIN] $player が参加しました" -ForegroundColor Green
    }
    
    if ($_ -match '\]:\s+(\S+)\s+left\s+the\s+game') {
        $player = $Matches[1]
        $players.Remove($player) | Out-Null
        Write-Host "[LEFT] $player が退出しました" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "最終結果"
Write-Host "=========================================" -ForegroundColor Green
Write-Host "現在のプレイヤー数: $($players.Count)" -ForegroundColor Cyan

if ($players.Count -eq 0) {
    Write-Host "現在のプレイヤー: なし" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ 全員退出しています。15分後に自動停止します。" -ForegroundColor Green
} else {
    $playerList = ($players.Keys | ForEach-Object { $_ }) -join ", "
    Write-Host "現在のプレイヤー: $playerList" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "❌ プレイヤーが接続中です。自動停止しません。" -ForegroundColor Red
}

Write-Host ""
