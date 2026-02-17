import json
import boto3
import os
import urllib.request
import urllib.parse

ssm = boto3.client('ssm', region_name='ap-northeast-1')
INSTANCE_ID = os.environ.get('INSTANCE_ID', 'i-0b3b312b21a19f71b')
DISCORD_BOT_URL = os.environ.get('DISCORD_BOT_URL', '')

def lambda_handler(event, context):
    try:
        # クエリパラメータからメッセージを取得
        params = event.get('queryStringParameters', {})
        
        if not params or 'message' not in params:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'message': 'メッセージが指定されていません'
                })
            }
        
        message = urllib.parse.unquote(params['message'])
        channel = params.get('channel', 'status')  # デフォルトはstatus
        
        # Discord Botに通知を送信
        if not DISCORD_BOT_URL:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'message': 'DISCORD_BOT_URLが設定されていません'
                })
            }
        
        notification_data = {
            'message': message,
            'channel': channel
        }
        
        req = urllib.request.Request(
            f'{DISCORD_BOT_URL}/notify',
            data=json.dumps(notification_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            response_data = json.loads(response.read().decode('utf-8'))
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': '通知を送信しました',
                    'bot_response': response_data
                })
            }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f'エラーが発生しました: {str(e)}'
            })
        }
