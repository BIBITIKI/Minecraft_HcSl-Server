# Lambda関数の待機処理改善

## 変更内容

### 停止処理（stop_server_improved.py）

**変更前:**
- 停止コマンドを送信した直後に応答を返す
- メッセージ: "🛑 Minecraftサーバーを安全に停止しています..."

**変更後:**
- EC2が完全に停止するまで待機（最大5分）
- 15秒ごとに状態をチェック
- 完全停止後にメッセージを返す
- メッセージ: "✅ Minecraftサーバーを安全に停止しました"

```python
# EC2が完全に停止するまで待機
waiter = ec2.get_waiter('instance_stopped')
waiter.wait(
    InstanceIds=[instance_id],
    WaiterConfig={
        'Delay': 15,  # 15秒ごとにチェック
        'MaxAttempts': 20  # 最大5分（15秒 × 20回）
    }
)
```

### 起動処理（start_server.py）

**変更前:**
- EC2起動後すぐにIPアドレスを返す
- メッセージ: "接続まで2-3分お待ちください"

**変更後:**
- EC2が完全に起動するまで待機
- さらに2分待機（Minecraftサーバーの起動完了を待つ）
- 接続可能になってからメッセージを返す
- メッセージ: "サーバーに接続できます"

```python
# EC2起動を待機
waiter = ec2.get_waiter('instance_running')
waiter.wait(
    InstanceIds=[instance_id],
    WaiterConfig={
        'Delay': 15,
        'MaxAttempts': 20
    }
)

# Minecraftサーバーの起動を待つ（追加で2分）
time.sleep(120)
```

## メリット

### 1. ユーザー体験の向上
- Discord Botのメッセージが正確になる
- 「停止しました」= 本当に停止完了
- 「起動しました」= すぐに接続可能

### 2. 混乱の防止
- 「停止中...」と表示されているのに既に停止している、という状況がなくなる
- IPアドレスが表示されたらすぐに接続できる

### 3. エラーハンドリング
- タイムアウト（5分）を設定
- 異常な状態を検知可能

## 注意事項

### Lambda実行時間
- 停止: 最大5分（通常30秒〜1分）
- 起動: 最大7分（EC2起動5分 + Minecraft起動2分）
- Lambda最大実行時間: 15分（十分な余裕あり）

### コスト影響
- Lambda実行時間が長くなるが、コスト増加は微々たるもの
- 月間100回起動/停止でも追加コストは数円程度

## Discord Botの表示例

### 起動時
```
ユーザー: /serverstart
Bot: 🚀 サーバー起動処理を開始します...
（約3分待機）
Bot: ✅ Minecraftサーバーが起動しました！

**サーバーアドレス**: `54.199.196.160:25565`

サーバーに接続できます。
```

### 停止時
```
ユーザー: /serverstop
Bot: 🛑 サーバー停止処理を開始します...
（約1分待機）
Bot: ✅ Minecraftサーバーを安全に停止しました
```

## デプロイ状況

✅ Lambda関数を更新しました
✅ Terraform apply完了
✅ 次回の起動/停止から新しい動作になります

## テスト方法

1. Discordで `/serverstop` を実行
2. 約1分待つ
3. "✅ Minecraftサーバーを安全に停止しました" が表示されることを確認
4. Discordで `/serverstart` を実行
5. 約3分待つ
6. IPアドレスが表示されたらすぐにMinecraftで接続テスト

## トラブルシューティング

### タイムアウトエラーが発生する場合
- EC2の状態を確認: `aws ec2 describe-instances --instance-ids i-0be762ecb97115b07`
- 手動で停止/起動を試す

### 待機時間が長すぎる場合
- `WaiterConfig`の`Delay`と`MaxAttempts`を調整可能
- 現在: 15秒 × 20回 = 最大5分
