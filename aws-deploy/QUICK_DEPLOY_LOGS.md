# ログ機能クイックデプロイ手順

## 現状
`/logs` コマンドを実行すると、Lambda関数がまだデプロイされていないため、エラーまたはハードコードされたサンプルログが表示されます。

## デプロイ手順

### 1. Lambda関数をZIP化

```powershell
cd Minecraft_HcSl-Server\aws-deploy\lambda
Compress-Archive -Path get_logs.py -DestinationPath get_logs.zip -Force
```

### 2. Terraformでデプロイ

```powershell
cd ..\terraform

# 初期化（初回のみ）
terraform init

# 変更内容を確認
terraform plan

# デプロイ実行
terraform apply
```

`yes` と入力してデプロイを確認します。

### 3. ログ取得URLを確認

デプロイ完了後、以下のコマンドでURLを取得:

```powershell
terraform output api_logs_url
```

出力例:
```
"https://mf71h6a5f9.execute-api.ap-northeast-1.amazonaws.com/prod/logs"
```

### 4. Railway.appに環境変数を追加

1. Railway.app → プロジェクトを開く
2. Variables タブをクリック
3. 新しい変数を追加:
   - Variable: `LAMBDA_LOGS_URL_HCSL`
   - Value: `https://mf71h6a5f9.execute-api.ap-northeast-1.amazonaws.com/prod/logs`
     （上記で取得したURL）

4. 保存すると自動的に再デプロイされます

### 5. 動作確認

Discord Botで以下を実行:

```
/start          # サーバーを起動
/logs           # ログを確認（最新50行）
/logs lines:100 # ログを確認（最新100行）
```

## トラブルシューティング

### エラー: "サーバーが起動していません"

サーバーが停止中の場合、ログは取得できません。先に `/start` でサーバーを起動してください。

### エラー: "ログの取得に失敗しました"

1. Lambda関数が正しくデプロイされているか確認:
   ```powershell
   aws lambda list-functions --query "Functions[?FunctionName=='minecraft-get-logs']"
   ```

2. API Gatewayのエンドポイントが正しいか確認:
   ```powershell
   terraform output api_logs_url
   ```

3. Railway.appの環境変数が正しく設定されているか確認

### ログが空の場合

Minecraftサーバーのログファイルパスを確認:
```bash
# EC2にSSH接続して確認
ls -la /opt/minecraft/logs/
```

デフォルトは `/opt/minecraft/logs/latest.log` です。

## コスト

- Lambda実行: $0.0000002/リクエスト
- API Gateway: $0.0000035/リクエスト
- SSM Command: 無料

月間100回実行しても $0.001 未満です。

## 次のステップ

デプロイが完了したら、以下の機能も検討できます:

1. ログのフィルタリング（特定のキーワードで検索）
2. ログのダウンロード（Discord添付ファイル）
3. リアルタイムログストリーミング
