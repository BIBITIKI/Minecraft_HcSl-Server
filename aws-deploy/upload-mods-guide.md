# MODファイルをEC2にアップロードする手順

## 方法1: AWS Systems Manager Session Manager経由（推奨）

### 1. EC2に接続

```powershell
aws ssm start-session --target i-0b3b312b21a19f71b --region ap-northeast-1
```

### 2. Minecraftサーバーを停止

```bash
sudo systemctl stop minecraft
```

### 3. MODフォルダを準備

```bash
cd /home/ubuntu/minecraft
mkdir -p mods_backup
mv mods/*.jar mods_backup/ 2>/dev/null || true
```

### 4. 別のPowerShellウィンドウで、各MODファイルをSSM経由でアップロード

以下のコマンドを各MODファイルに対して実行してください：

```powershell
# Ancient-Obelisks
$modFile = "C:\Kiro\Minecraft_HcSl-Server\mods\Ancient-Obelisks-1.20.1-1.2.3.jar"
$modName = "Ancient-Obelisks-1.20.1-1.2.3.jar"
$bytes = [System.IO.File]::ReadAllBytes($modFile)
$base64 = [System.Convert]::ToBase64String($bytes)
$cmd = "echo '$base64' | base64 -d > /home/ubuntu/minecraft/mods/$modName"
aws ssm send-command --instance-ids i-0b3b312b21a19f71b --region ap-northeast-1 --document-name "AWS-RunShellScript" --parameters commands="$cmd"

# curios-forge
$modFile = "C:\Kiro\Minecraft_HcSl-Server\mods\curios-forge-5.14.1+1.20.1.jar"
$modName = "curios-forge-5.14.1+1.20.1.jar"
$bytes = [System.IO.File]::ReadAllBytes($modFile)
$base64 = [System.Convert]::ToBase64String($bytes)
$cmd = "echo '$base64' | base64 -d > /home/ubuntu/minecraft/mods/$modName"
aws ssm send-command --instance-ids i-0b3b312b21a19f71b --region ap-northeast-1 --document-name "AWS-RunShellScript" --parameters commands="$cmd"

# 他のMODファイルも同様に...
```

### 5. EC2セッションに戻り、権限を設定してサーバーを起動

```bash
cd /home/ubuntu/minecraft
sudo chown -R ubuntu:ubuntu mods
sudo systemctl start minecraft
```

## 方法2: S3経由（大きなファイルに推奨）

### 1. S3バケットを作成（まだない場合）

```powershell
aws s3 mb s3://minecraft-mods-temp-bucket --region ap-northeast-1
```

### 2. MODファイルをS3にアップロード

```powershell
cd C:\Kiro\Minecraft_HcSl-Server
aws s3 sync mods s3://minecraft-mods-temp-bucket/mods/ --region ap-northeast-1
```

### 3. EC2に接続

```powershell
aws ssm start-session --target i-0b3b312b21a19f71b --region ap-northeast-1
```

### 4. EC2でMODファイルをダウンロード

```bash
sudo systemctl stop minecraft
cd /home/ubuntu/minecraft
mkdir -p mods_backup
mv mods/*.jar mods_backup/ 2>/dev/null || true
aws s3 sync s3://minecraft-mods-temp-bucket/mods/ mods/ --region ap-northeast-1
sudo chown -R ubuntu:ubuntu mods
sudo systemctl start minecraft
```

### 5. S3バケットを削除（オプション）

```powershell
aws s3 rb s3://minecraft-mods-temp-bucket --force
```

## 方法3: 自動スクリプト（小さいファイルのみ）

以下のスクリプトを実行してください：

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy
.\upload-mods-auto.ps1
```

注意: このスクリプトはSSMの制限により、小さいファイル（<5MB）のみ対応しています。
