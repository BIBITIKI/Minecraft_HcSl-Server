# ログ取得機能のデプロイ手順

## 概要

Discord Botの `/logs` コマンドで実際のMinecraftサーバーログを取得できるようにします。

## 前提条件

- Terraformがインストールされている
- AWS CLIが設定されている
- 既存のMinecraftサーバーインフラが稼働している

## デプロイ手順

### 1. Lambda関数をZIP化

```powershell
cd Minecraft_HcSl-Server/aws-deploy/lambda

# get_logs.pyをZIP化
Compress-Archive -Path get_logs.py -DestinationPath get_logs.zip -Force
```

### 2. Terraformでデプロイ

```powershell
cd ../terraform

# 変更内容を確認
terraform plan

# デプロイ実行
terraform apply
```

### 3. API Gateway URLを取得

デプロイ完了後、以下のコマンドでログ取得URLを確認:

```powershell
terraform output lambda_logs_url
```

出力例:
```
https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/prod/logs
```

### 4. Railway.appの環境変数を更新

Railway.app → Variables タブで以下を追加:

```
LAMBDA_LOGS_URL_HCSL=https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/prod/logs
```

### 5. config-generator.jsを更新

`Node-File-System/Node-File-System/config-generator.js` で、`lambdaLogsUrl` を環境変数から読み込むように設定:

```javascript
lambdaLogsUrl: process.env[`LAMBDA_LOGS_URL_${serverIdUpper}`]
```

### 6. Railway.appで再デプロイ

環境変数を追加したら、Railway.appが自動的に再デプロイします。

## 使い方

Discord Botで以下のコマンドを実行:

```
/logs
/logs lines:100
```

- デフォルトは最新50行
- `lines` オプションで行数を指定可能（最大1000行推奨）

## 動作確認

1. サーバーを起動: `/start`
2. サーバーが起動したら: `/logs`
3. 実際のMinecraftサーバーログが表示されることを確認

## トラブルシューティング

### ログが取得できない

1. サーバーが起動しているか確認: `/status`
2. ログファイルのパスを確認: `/opt/minecraft/logs/latest.log`
3. EC2インスタンスにSSM権限があるか確認（既存のIAMロールに含まれているはず）

### エラー: "サーバーが起動していません"

サーバーが停止中の場合、ログは取得できません。先に `/start` でサーバーを起動してください。

### エラー: "ログの取得に失敗しました"

Lambda関数のCloudWatch Logsを確認:
```powershell
aws logs tail /aws/lambda/minecraft-get-logs --follow
```

## コスト

- Lambda実行: $0.0000002/リクエスト（ほぼ無料）
- API Gateway: $0.0000035/リクエスト（ほぼ無料）
- SSM Command: 無料

月間100回実行しても $0.001 未満です。

## セキュリティ

- API Gatewayは認証なし（NONE）ですが、インスタンスIDは環境変数で管理
- SSM経由でログを取得するため、SSH不要
- ログは読み取り専用（tail -n コマンド）

## 今後の拡張

- ログのフィルタリング機能（特定のキーワードで検索）
- ログのダウンロード機能（Discord添付ファイル）
- リアルタイムログストリーミング（WebSocket）
