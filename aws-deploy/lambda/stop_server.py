import boto3
import os
import json
import urllib.request

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
            return {
                'statusCode': 200,
                'body': json.dumps({'message': message})
            }
        
        if state != 'running':
            message = f'サーバーは現在 {state} 状態です'
            return {
                'statusCode': 400,
                'body': json.dumps({'message': message})
            }
        
        # SSM経由で安全にMinecraftサーバーを停止（非同期）
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
            
            # 即座に応答を返す（停止処理は裏で継続）
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Server stop command sent successfully',
                    'state': 'stopping'
                })
            }
            
        except Exception as ssm_error:
            # SSMが使えない場合は直接停止
            print(f'SSM failed, using direct stop: {ssm_error}')
            ec2.stop_instances(InstanceIds=[instance_id])
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Server stop command sent successfully',
                    'state': 'stopping'
                })
            }
        
    except Exception as e:
        error_message = f'❌ エラーが発生しました: {str(e)}'
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
