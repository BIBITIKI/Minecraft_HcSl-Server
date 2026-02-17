# 待機メカニズムの説明

## 質問: 待機は固定？それともトリガーベース？

## 回答: 両方使っています

---

## 1. EC2の起動/停止待機（トリガーベース）

### 使用技術: AWS Waiter

```python
waiter = ec2.get_waiter('instance_stopped')  # または 'instance_running'
waiter.wait(
    InstanceIds=[instance_id],
    WaiterConfig={
        'Delay': 15,  # 15秒ごとにチェック
        'MaxAttempts': 20  # 最大20回（5分）
    }
)
```

### 動作方法: ポーリング（定期チェック）

1. **15秒ごと**にAWS APIを呼び出してEC2の状態を確認
2. 状態が目的の状態（`stopped`または`running`）になったら**即座に**次の処理へ
3. 最大20回チェック（5分）しても完了しなければタイムアウトエラー

### メリット
- ✅ 実際の状態変化を検知
- ✅ 無駄な待機時間なし
- ✅ 早く完了すれば早く応答

### 例
- EC2停止が30秒で完了 → 30秒で応答
- EC2停止が2分かかる → 2分で応答
- 5分経っても停止しない → タイムアウトエラー

---

## 2. Minecraftサーバー起動待機（ハイブリッド）

### 最新の実装（改善版）

```python
# SSM経由でMinecraftサービスの状態をチェック
max_wait_time = 180  # 最大3分
check_interval = 15  # 15秒ごとにチェック

while elapsed_time < max_wait_time:
    # systemctl is-active minecraft.service を実行
    if 'active' in result:
        # サービスがアクティブになったら追加30秒待機
        time.sleep(30)
        break
    time.sleep(15)

# SSMチェックが失敗した場合は固定2分待機（フォールバック）
if not minecraft_ready:
    time.sleep(120)
```

### 動作方法: ポーリング + 固定待機

1. **15秒ごと**にSSM経由で`systemctl is-active minecraft.service`を実行
2. サービスが`active`になったら検知
3. さらに**30秒固定待機**（サーバー起動完了を確実にする）
4. SSMが使えない場合は**2分固定待機**（フォールバック）

### メリット
- ✅ サービスの起動を検知
- ✅ 早く起動すれば早く応答
- ✅ SSM失敗時のフォールバック

### 例
- Minecraftが1分で起動 → 1分30秒で応答
- Minecraftが2分で起動 → 2分30秒で応答
- SSMが使えない → 2分固定待機

---

## 3. 停止処理の待機（トリガーベース）

### 実装

```python
# SSM経由で安全に停止
ssm.send_command(
    Parameters={'commands': [
        'systemctl stop minecraft.service',
        'sleep 10',
        'shutdown -h now'
    ]}
)

# EC2が完全に停止するまで待機
waiter = ec2.get_waiter('instance_stopped')
waiter.wait(InstanceIds=[instance_id])
```

### 動作方法: トリガーベース

1. Minecraftサービスを停止
2. 10秒待機（データ保存）
3. EC2をシャットダウン
4. **EC2の状態を15秒ごとにチェック**
5. `stopped`状態になったら即座に応答

### メリット
- ✅ 完全停止を確認
- ✅ 無駄な待機なし

---

## まとめ

| 処理 | 待機方法 | チェック間隔 | 最大待機時間 |
|------|---------|------------|------------|
| EC2起動 | トリガー（Waiter） | 15秒 | 5分 |
| EC2停止 | トリガー（Waiter） | 15秒 | 5分 |
| Minecraft起動 | ポーリング + 固定 | 15秒 | 3分 + 30秒 |
| Minecraft停止 | 固定（SSMコマンド内） | - | 10秒 |

## 待機時間の例

### 起動処理
```
Discord: /serverstart
↓
Lambda: EC2起動コマンド送信
↓ 15秒ごとにチェック
EC2: running状態になった（約1分）
↓
Lambda: Minecraftサービスをチェック開始
↓ 15秒ごとにチェック
Minecraft: active状態になった（約1分）
↓ 固定30秒待機
Lambda: 応答を返す
↓
Discord: "✅ サーバーに接続できます"

合計: 約2分30秒
```

### 停止処理
```
Discord: /serverstop
↓
Lambda: SSM経由で停止コマンド送信
↓
EC2: Minecraftサービス停止（10秒）
EC2: シャットダウン開始
↓ 15秒ごとにチェック
EC2: stopped状態になった（約30秒）
↓
Lambda: 応答を返す
↓
Discord: "✅ 安全に停止しました"

合計: 約40秒
```

## 改善の余地

### さらに正確にするには

1. **Minecraftログをチェック**
   - `tail -f /minecraft/server/logs/latest.log | grep "Done"`
   - "Done"メッセージが出たら起動完了

2. **ポート25565をチェック**
   - `nc -zv localhost 25565`
   - ポートが開いたら接続可能

3. **RCON接続をチェック**
   - RCONで`list`コマンドを実行
   - 応答があれば完全起動

### 現在の実装を選んだ理由

- ✅ シンプルで信頼性が高い
- ✅ SSMが使えない場合のフォールバックあり
- ✅ 十分な精度（30秒程度の誤差は許容範囲）
- ✅ Lambda実行時間が短い（コスト削減）

---

## トラブルシューティング

### 待機時間が長すぎる場合

**原因:**
- EC2の起動が遅い
- Minecraftサーバーの起動が遅い
- SSMエージェントが起動していない

**対処:**
1. EC2のログを確認: `journalctl -u minecraft.service`
2. SSMエージェントの状態を確認: `systemctl status amazon-ssm-agent`
3. `WaiterConfig`の`Delay`を調整（現在15秒）

### タイムアウトエラーが発生する場合

**原因:**
- EC2が5分以内に起動/停止しない
- Minecraftが3分以内に起動しない

**対処:**
1. `MaxAttempts`を増やす（現在20回）
2. EC2のインスタンスタイプを確認（t3a.mediumで十分か）
3. 手動で起動/停止を試してみる
