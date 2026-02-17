# キーペアエラーの解決方法

## エラー内容
```
Error: creating EC2 Instance: operation error EC2: RunInstances, 
api error InvalidKeyPair.NotFound: The key pair 'minecraft-server-key' does not exist
```

## 原因
terraform.tfvarsで指定したキーペア名 `minecraft-server-key` がAWS上に存在しない

## 解決方法（3つの選択肢）

### 方法1: PowerShellスクリプトで自動作成（推奨・最速）

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy
.\create-keypair.ps1
```

これで以下が自動実行されます:
- AWSにキーペア作成
- .pemファイルをホームディレクトリに保存
- terraform.tfvarsの設定確認

### 方法2: AWS CLIで手動作成

```powershell
# キーペア作成
aws ec2 create-key-pair --key-name minecraft-server-key --query 'KeyMaterial' --output text > $HOME\minecraft-server-key.pem

# 確認
aws ec2 describe-key-pairs --key-names minecraft-server-key
```

### 方法3: AWS Management Consoleで作成

1. AWS Console → EC2 → キーペア
2. 「キーペアを作成」をクリック
3. 以下を入力:
   - 名前: `minecraft-server-key`
   - キータイプ: RSA
   - プライベートキーファイル形式: .pem
4. 「キーペアを作成」をクリック
5. ダウンロードされた`.pem`ファイルを保存

## 作成後の確認

```powershell
# キーペアが存在するか確認
aws ec2 describe-key-pairs --key-names minecraft-server-key

# terraform.tfvarsの内容確認
cat aws-deploy\terraform\terraform.tfvars
```

terraform.tfvarsに以下が設定されていることを確認:
```hcl
key_pair_name = "minecraft-server-key"
```

## Terraform再実行

```powershell
cd aws-deploy\terraform
terraform apply
```

## トラブルシューティング

### エラー: "UnauthorizedOperation"
AWS認証情報が設定されていません
```powershell
aws configure
aws sts get-caller-identity
```

### エラー: "InvalidKeyPair.Duplicate"
既にキーペアが存在します
```powershell
# 既存のキーペアを削除
aws ec2 delete-key-pair --key-name minecraft-server-key

# 再作成
.\create-keypair.ps1
```

### .pemファイルの権限エラー（Linux/Mac）
```bash
chmod 400 ~/minecraft-server-key.pem
```

## 次のステップ

キーペア作成後:
1. `terraform apply` を再実行
2. EC2インスタンスが作成される
3. Public IPが出力される
4. サーバーファイルをアップロード

詳細は `QUICK_START.md` を参照
