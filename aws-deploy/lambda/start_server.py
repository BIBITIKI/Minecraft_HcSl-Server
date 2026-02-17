import boto3
import time
import os
import json
import urllib.request

def lambda_handler(event, context):
    instance_id = os.environ['INSTANCE_ID']
    webhook_url = os.environ.get('WEBHOOK_URL', '')
    
    ec2 = boto3.client('ec2')
    
    try:
        # インスタンスの状態を確認
        response = ec2.describe_instances(InstanceIds=[instance_id])
        state = response['Reservations'][0]['Instances'][0]['State']['Name']
        
        if state == 'running':
            message = f'サーバーは既に起動しています'
            send_discord_message(webhook_url, message)
            return {
                'statusCode': 200,
                'body': json.dumps({'message': message})
            }
        
        # インスタンスを起動
        ec2.start_instances(InstanceIds=[instance_id])
        
        # 起動を待機（EC2が完全に起動するまで）
        waiter = ec2.get_waiter('instance_running')
        waiter.wait(
            InstanceIds=[instance_id],
            WaiterConfig={
                'Delay': 15,  # 15秒ごとにチェック
                'MaxAttempts': 20  # 最大5分
            }
        )
        
        # Public IPを取得
        response = ec2.describe_instances(InstanceIds=[instance_id])
        public_ip = response['Reservations'][0]['Instances'][0].get('PublicIpAddress', 'N/A')
        
        # Minecraftサーバーの起動を待つ（SSM経由でサービス状態をチェック）
        ssm = boto3.client('ssm')
        max_wait_time = 180  # 最大3分
        check_interval = 15  # 15秒ごとにチェック
        elapsed_time = 0
        minecraft_ready = False
        
        while elapsed_time < max_wait_time:
            try:
                # SSM経由でMinecraftサービスの状態をチェック
                response = ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName='AWS-RunShellScript',
                    Parameters={
                        'commands': [
                            'systemctl is-active minecraft.service'
                        ]
                    }
                )
                
                command_id = response['Command']['CommandId']
                time.sleep(5)  # コマンド実行を待つ
                
                # コマンド結果を取得
                result = ssm.get_command_invocation(
                    CommandId=command_id,
                    InstanceId=instance_id
                )
                
                if result['Status'] == 'Success' and 'active' in result['StandardOutputContent']:
                    # Minecraftサービスがアクティブ
                    # さらに30秒待ってサーバー起動完了を確実にする
                    time.sleep(30)
                    minecraft_ready = True
                    break
                    
            except Exception as e:
                print(f'SSM check failed: {e}')
            
            time.sleep(check_interval)
            elapsed_time += check_interval
        
        # SSMチェックが失敗した場合は固定2分待機
        if not minecraft_ready:
            print('SSM check failed, using fixed wait time')
            time.sleep(120)
        
        message = f'✅ Minecraftサーバーが起動しました！\n\n**サーバーアドレス**: `{public_ip}:25565`\n\nサーバーに接続できます。'
        send_discord_message(webhook_url, message)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Server started successfully',
                'public_ip': public_ip
            })
        }
        
    except Exception as e:
        error_message = f'❌ エラーが発生しました: {str(e)}'
        send_discord_message(webhook_url, error_message)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def send_discord_message(webhook_url, message):
    if not webhook_url:
        return
    
    data = json.dumps({'content': message}).encode('utf-8')
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        urllib.request.urlopen(req)
    except Exception as e:
        print(f'Failed to send Discord message: {e}')
