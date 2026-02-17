import json
import os
import urllib.request
import urllib.parse

def lambda_handler(event, context):
    """
    Discord通知を送信するLambda関数
    Railway.appで動作しているDiscord BotのHTTPエンドポイントに通知を送信
    """
    
    # クエリパラメータから取得
    params = event.get('queryStringParameters', {}) or {}
    message = params.get('message', '')
    channel = params.get('channel', 'status')  # デフォルトはstatus
    
    if not message:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'success': False,
                'message': 'Message parameter is required'
            })
        }
    
    # Railway.appのDiscord Bot HTTPエンドポイント
    # 環境変数から取得（設定されていない場合はエラー）
    bot_url = os.environ.get('DISCORD_BOT_URL')
    
    if not bot_url:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': 'DISCORD_BOT_URL environment variable not set'
            })
        }
    
    # URLデコード
    message = urllib.parse.unquote(message)
    
    # Discord Botに通知を送信
    try:
        data = json.dumps({
            'message': message,
            'channel': channel
        }).encode('utf-8')
        
        req = urllib.request.Request(
            f'{bot_url}/notify',
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            response_data = response.read().decode('utf-8')
            print(f'Discord notification sent: {response_data}')
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': 'Notification sent to Discord',
                    'channel': channel
                })
            }
    
    except Exception as e:
        print(f'Error sending Discord notification: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f'Failed to send notification: {str(e)}'
            })
        }
