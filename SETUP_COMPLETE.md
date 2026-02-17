# Minecraft Server セットアップ完了

## 完了した設定

### インフラ構成
- ✅ EC2インスタンス: t3a.medium（ap-northeast-1）
- ✅ EBS: 30GB gp3
- ✅ セキュリティグループ: SSH(22), Minecraft(25565)
- ✅ IAMロール: EC2自己停止権限 + SSM権限
- ✅ Lambda関数: 起動/停止（SSM経由で安全な停止）
- ✅ EventBridge: 深夜3時自動停止

### 自動化機能
- ✅ Discord経由でサーバー起動/停止
- ✅ 起動時に動的IPアドレスを自動通知
- ✅ 深夜3時（JST）に自動停止
- ✅ 15分間プレイヤー不在で自動停止
- ✅ 監視スクリプトは起動時に自動起動

### コスト最適化
- ✅ Elastic IP削除（-432円/月）
- ✅ 月額コスト: 約2,208円

## 現在のサーバー情報

**インスタンスID**: `i-0be762ecb97115b07`
**現在のIP**: `35.79.13.115`（次回起動時に変わります）

**Lambda URL**:
- 起動: `https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/`
- 停止: `https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/`

## 次のステップ

### 1. Discord Webhook設定（必須）

`terraform.tfvars`に以下を追加:

```hcl
discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
```

設定後、再適用:

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy\terraform
terraform apply -auto-approve
```

### 2. Discord Bot設定（推奨）

詳細は `DISCORD_QUICK_SETUP.md` を参照してください。

1. Discord Developer Portalでアプリ作成
2. Botトークンを取得
3. Glitchでホスティング
4. `/serverstart`, `/serverstop`, `/serverstatus` コマンドが使用可能

### 3. 動作確認

#### サーバー起動テスト

```powershell
# Lambda経由で起動
curl https://wxefluc2qfy2dd32czkvefeozi0yetwi.lambda-url.ap-northeast-1.on.aws/

# 起動確認
aws ec2 describe-instances --instance-ids i-0be762ecb97115b07 --query "Reservations[0].Instances[0].State.Name"
```

#### サーバー停止テスト

```powershell
# Lambda経由で停止（安全な停止処理）
curl https://hvyt42jkwftvbrxhepo27ikisa0xxwtw.lambda-url.ap-northeast-1.on.aws/
```

#### 自動停止監視ログ確認

```bash
# EC2にSSH接続後
sudo tail -f /var/log/minecraft-autoshutdown.log
```

## トラブルシューティング

### サーバーが起動しない

```powershell
# インスタンスの状態確認
aws ec2 describe-instances --instance-ids i-0be762ecb97115b07

# Lambda関数のログ確認
aws logs tail /aws/lambda/minecraft-start-server --follow
```

### サーバーが停止しない

```powershell
# Lambda関数のログ確認
aws logs tail /aws/lambda/minecraft-stop-server --follow

# SSM経由でコマンド実行確認
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-0be762ecb97115b07"
```

### 自動停止が動作しない

```bash
# EC2にSSH接続後
sudo systemctl status minecraft-autoshutdown.service
sudo journalctl -u minecraft-autoshutdown.service -f
```

## コスト内訳

### 月額コスト（約2,208円）

| 項目 | 月額 |
|------|------|
| EC2 t3a.medium | 1,920円 |
| EBS 30GB gp3 | 288円 |
| Lambda（無料枠内） | 0円 |
| EventBridge（無料枠内） | 0円 |
| **合計** | **2,208円** |

### さらにコストを削減するには

`COST_OPTIMIZATION.md` を参照してください:

- t3a.smallにダウングレード: 月額1,248円（-960円）
- Reserved Instance（1年契約）: 月額1,584円（-624円）
- 自動停止の活用: 月額約600円（月180時間稼働想定）

## 安全な停止処理について

Lambda stop関数は以下の手順で安全に停止します:

1. SSM経由で`systemctl stop minecraft.service`を実行
2. 10秒待機（データ保存完了を待つ）
3. `shutdown -h now`でEC2を停止

これにより、ワールドデータの破損を防ぎます。

## 監視スクリプトについて

`minecraft-autoshutdown.service`は以下の動作をします:

- Minecraftログから"joined the game"/"left the game"を監視
- プレイヤーごとに在線状態を追跡
- 全員がログアウトしてから15分後に自動停止
- EC2起動時に自動起動（`systemctl enable`済み）

## ファイル構成

```
Minecraft_HcSl-Server/
├── aws-deploy/
│   ├── terraform/
│   │   ├── main.tf              # EC2, IAM, セキュリティグループ
│   │   ├── lambda.tf            # Lambda関数、EventBridge
│   │   ├── variables.tf         # 変数定義
│   │   └── terraform.tfvars     # 変数値（要編集）
│   ├── lambda/
│   │   ├── start_server.py      # 起動Lambda
│   │   ├── stop_server.py       # 停止Lambda（SSM対応）
│   │   ├── start_server.zip     # デプロイ用
│   │   └── stop_server.zip      # デプロイ用
│   ├── user-data.sh             # EC2初期化スクリプト
│   └── auto-shutdown.sh         # 自動停止監視スクリプト
├── DISCORD_QUICK_SETUP.md       # Discord Bot設定ガイド
├── COST_OPTIMIZATION.md         # コスト最適化ガイド
└── SETUP_COMPLETE.md            # このファイル
```

## サポート

問題が発生した場合は、以下を確認してください:

1. Lambda関数のログ
2. EC2インスタンスのシステムログ
3. Minecraftサーバーログ（`/minecraft/server/logs/latest.log`）
4. 自動停止監視ログ（`/var/log/minecraft-autoshutdown.log`）

---

セットアップ完了日: 2026年2月15日
