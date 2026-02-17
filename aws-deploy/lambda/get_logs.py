import json
import boto3
import os

ssm = boto3.client('ssm', region_name='ap-northeast-1')
ec2 = boto3.client('ec2', region_name='ap-northeast-1')

INSTANCE_ID = os.environ.get('INSTANCE_ID', 'i-0b3b312b21a19f71b')

def lambda_handler(event, context):
    try:
        # クエリパラメータから行数を取得（デフォルト50行）
        lines = 50
        if event.get('queryStringParameters'):
            lines = int(event['queryStringParameters'].get('lines', 50))
        
        # インスタンスの状態を確認
        response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
        state = response['Reservations'][0]['Instances'][0]['State']['Name']
        
        if state != 'running':
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': False,
                    'message': f'サーバーが起動していません（状態: {state}）',
                    'logs': []
                })
            }
        
        # SSM経由でログを取得
        command = f'tail -n {lines} /minecraft/server/logs/latest.log'
        
        ssm_response = ssm.send_command(
            InstanceIds=[INSTANCE_ID],
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': [command]},
            TimeoutSeconds=30
        )
        
        command_id = ssm_response['Command']['CommandId']
        
        # コマンド実行完了を待つ
        import time
        max_attempts = 10
        for attempt in range(max_attempts):
            time.sleep(1)
            
            output = ssm.get_command_invocation(
                CommandId=command_id,
                InstanceId=INSTANCE_ID
            )
            
            if output['Status'] in ['Success', 'Failed']:
                break
        
        if output['Status'] == 'Success':
            log_content = output['StandardOutputContent']
            log_lines = log_content.strip().split('\n') if log_content else []
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': f'最新{len(log_lines)}行のログを取得しました',
                    'logs': log_lines
                })
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': False,
                    'message': 'ログの取得に失敗しました',
                    'logs': [],
                    'error': output.get('StandardErrorContent', 'Unknown error')
                })
            }
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f'エラーが発生しました: {str(e)}',
                'logs': []
            })
        }
