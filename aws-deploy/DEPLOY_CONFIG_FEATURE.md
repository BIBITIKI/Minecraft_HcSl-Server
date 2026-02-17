# 設定変更機能のデプロイ手順

## 概要

Discord Botの `/config` コマンドで自動停止時間（IDLE_TIME）を動的に変更できるようにします。

## 機能

- `/config` - 現在の設定を表示
- `/config idle_time:10` - 自動停止時間を10分に設定
- 設定はSSM Parameter Storeに保存され、サーバー再起動後も永続化
- 範囲: 1〜60分

## デプロイ手順

### 1. Lambda関数をZIP化

```powershell
cd Minecraft_HcSl-Server\aws-deploy\lambda
Compress-Archive -Path update_config.py -DestinationPath update_config.zip -Force
```

### 2. Terraformでデプロイ

```powershell
cd ..\terraform
terraform plan
terraform apply
```

### 3. API Gateway URLを取得

```powershell
terraform output api_config_url
```

出力例:
```
"https://mf71h6a5f9.execute-api.ap-northeast-1.amazonaws.com/prod/config"
```

### 4. Railway.appに環境変数を追加

```
LAMBDA_CONFIG_URL_HCSL=https://mf71h6a5f9.execute-api.ap-northeast-1.amazonaws.com/prod/config
```

### 5. EC2インスタンスのuser-dataを更新

`user-data.sh` の auto-shutdown.sh が更新されているため、次回サーバー起動時から自動的に反映されます。

既存のサーバーに反映する場合は、SSM経由でスクリプトを更新:

```bash
# SSM Session Managerで接続
aws ssm start-session --target i-0b3b312b21a19f71b

# スクリプトを更新
sudo systemctl stop minecraft-autoshutdown
sudo curl -o /opt/minecraft/auto-shutdown.sh https://raw.githubusercontent.com/.../auto-shutdown.sh
sudo chmod +x /opt/minecraft/auto-shutdown.sh
sudo systemctl start minecraft-autoshutdown
```

## 使い方

### 現在の設定を確認

```
/config
```

出力例:
```
⚙️ 現在の設定

自動停止時間: 15分

変更するには: /config idle_time:<分数>
```

### 設定を変更

```
/config idle_time:10
```

出力例:
```
✅ 自動停止時間を10分に設定しました

注意: 次回サーバー起動時から有効になります
```

## 動作の仕組み

1. `/config idle_time:10` を実行
2. Lambda関数がSSM Parameter Storeに設定を保存
   - パラメータ名: `/minecraft/i-0b3b312b21a19f71b/idle_time`
   - 値: `600`（秒）
3. 次回サーバー起動時、`auto-shutdown.sh` がParameter Storeから設定を読み込み
4. 指定した時間（10分）でプレイヤー不在を監視

## 設定の永続化

- SSM Parameter Storeに保存されるため、サーバー再起動後も設定が保持されます
- EC2インスタンスを削除しない限り、設定は永続化されます

## トラブルシューティング

### エラー: "設定の取得に失敗しました"

1. Lambda関数が正しくデプロイされているか確認:
   ```powershell
   aws lambda list-functions --query "Functions[?FunctionName=='minecraft-update-config']"
   ```

2. API Gatewayのエンドポイントが正しいか確認:
   ```powershell
   terraform output api_config_url
   ```

### 設定が反映されない

1. サーバーを再起動してください（設定は次回起動時から有効）
2. auto-shutdown.shのログを確認:
   ```bash
   sudo tail -f /var/log/minecraft-autoshutdown.log
   ```

起動時に以下のようなログが表示されるはずです:
```
[2026-02-17 12:00:00] =========================================
[2026-02-17 12:00:00] Auto-shutdown monitor started (improved version)
[2026-02-17 12:00:00] Server will stop after 600 seconds (10 minutes) of no players
[2026-02-17 12:00:00] Instance ID: i-0b3b312b21a19f71b, Region: ap-northeast-1
[2026-02-17 12:00:00] =========================================
```

## コスト

- Lambda実行: $0.0000002/リクエスト
- API Gateway: $0.0000035/リクエスト
- SSM Parameter Store: 無料（標準パラメータ）

月間100回変更しても $0.001 未満です。

## セキュリティ

- `/config` コマンドは管理者のみ実行可能
- 設定範囲は1〜60分に制限
- SSM Parameter Storeは暗号化可能（オプション）

## 今後の拡張

- メモリ割り当ての変更
- バックアップ頻度の設定
- Discord通知のON/OFF
- プレイヤー数上限の変更
