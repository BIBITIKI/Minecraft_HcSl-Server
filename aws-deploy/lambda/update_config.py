import json
import boto3
import os

ssm = boto3.client('ssm', region_name='ap-northeast-1')
INSTANCE_ID = os.environ.get('INSTANCE_ID', 'i-0b3b312b21a19f71b')

def lambda_handler(event, context):
    try:
        # クエリパラメータから設定を取得
        params = event.get('queryStringParameters', {})
        
        if not params:
            # 現在の設定を取得
            try:
                idle_time_param = ssm.get_parameter(Name=f'/minecraft/{INSTANCE_ID}/idle_time')
                idle_time = int(idle_time_param['Parameter']['Value'])
            except ssm.exceptions.ParameterNotFound:
                idle_time = 900  # デフォルト15分
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'config': {
                        'idle_time': idle_time,
                        'idle_time_minutes': idle_time // 60
                    }
                })
            }
        
        # 設定を更新
        if 'idle_time' in params:
            idle_time = int(params['idle_time'])
            
            # 範囲チェック（1分〜60分）
            if idle_time < 60 or idle_time > 3600:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'message': 'idle_timeは60〜3600秒（1〜60分）の範囲で指定してください'
                    })
                }
            
            # SSM Parameter Storeに保存
            ssm.put_parameter(
                Name=f'/minecraft/{INSTANCE_ID}/idle_time',
                Value=str(idle_time),
                Type='String',
                Overwrite=True,
                Description='Minecraft server auto-shutdown idle time (seconds)'
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': f'自動停止時間を{idle_time // 60}分に設定しました',
                    'config': {
                        'idle_time': idle_time,
                        'idle_time_minutes': idle_time // 60
                    }
                })
            }
        
        return {
            'statusCode': 400,
            'body': json.dumps({
                'success': False,
                'message': 'パラメータが不正です'
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
