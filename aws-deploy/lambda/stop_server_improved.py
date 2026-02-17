import boto3
import os
import json
import urllib.request
import time

def lambda_handler(event, context):
    instance_id = os.environ['INSTANCE_ID']
    webhook_url = os.environ.get('WEBHOOK_URL', '')
    
    ec2 = boto3.client('ec2')
    ssm = boto3.client('ssm')
    
    try:
        # インスタンスの状態を確認
        response = ec2.describe_instances(InstanceIds=[instance_id])
        state = response['Reservations'][0]['Instances'][0]['State']['Name']
        
        if state == 'stopped':
            message = 'サーバーは既に停止しています'
            send_discord_message(webhook_url, message)
            return {
                'statusCode': 200,
                'body': json.dumps({'message': message})
            }
        
        if state != 'running':
            message = f'サーバーは現在 {state} 状態です'
            send_discord_message(webhook_url, message)
            return {
                'statusCode': 400,
                'body': json.dumps({'message': message})
            }
        
        # SSM経由で安全にMinecraftサーバーを停止
        try:
            ssm_response = ssm.send_command(
                InstanceIds=[instance_id],
                DocumentName='AWS-RunShellScript',
                Parameters={
                    'commands': [
                        'systemctl stop minecraft.service',
                        'sleep 10',
                        'shutdown -h now'
                    ]
                }
            )
            
            # EC2が完全に停止するまで待機（最大5分）
            waiter = ec2.get_waiter('instance_stopped')
            waiter.wait(
                InstanceIds=[instance_id],
                WaiterConfig={
                    'Delay': 15,  # 15秒ごとにチェック
                    'MaxAttempts': 20  # 最大5分（15秒 × 20回）
                }
            )
            
            message = '✅ Minecraftサーバーを安全に停止しました'
            send_discord_message(webhook_url, message)
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Server stopped successfully'})
            }
            
        except Exception as ssm_error:
            # SSMが使えない場合は直接停止
            print(f'SSM failed, using direct stop: {ssm_error}')
            ec2.stop_instances(InstanceIds=[instance_id])
            
            # EC2が完全に停止するまで待機
            waiter = ec2.get_waiter('instance_stopped')
            waiter.wait(
                InstanceIds=[instance_id],
                WaiterConfig={
                    'Delay': 15,
                    'MaxAttempts': 20
                }
            )
            
            message = '✅ Minecraftサーバーを停止しました'
            send_discord_message(webhook_url, message)
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Server stopped successfully'})
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
