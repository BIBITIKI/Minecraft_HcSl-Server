import boto3
import os
import json
import time

def lambda_handler(event, context):
    instance_id = os.environ['INSTANCE_ID']
    
    ec2 = boto3.client('ec2')
    ssm = boto3.client('ssm')
    
    try:
        # EC2の状態を確認
        response = ec2.describe_instances(InstanceIds=[instance_id])
        state = response['Reservations'][0]['Instances'][0]['State']['Name']
        public_ip = response['Reservations'][0]['Instances'][0].get('PublicIpAddress', 'N/A')
        
        if state != 'running':
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'ready': False,
                    'state': state,
                    'public_ip': public_ip,
                    'message': f'EC2 is {state}'
                })
            }
        
        # SSM経由でMinecraftログをチェック
        try:
            ssm_response = ssm.send_command(
                InstanceIds=[instance_id],
                DocumentName='AWS-RunShellScript',
                Parameters={
                    'commands': [
                        # Minecraftが起動完了したかチェック（"Done ("メッセージを探す）
                        'if [ -f /minecraft/server/logs/latest.log ]; then',
                        '  if grep -q "Done (" /minecraft/server/logs/latest.log; then',
                        '    echo "MINECRAFT_READY"',
                        '  else',
                        '    echo "MINECRAFT_STARTING"',
                        '  fi',
                        'else',
                        '  echo "MINECRAFT_NOT_STARTED"',
                        'fi'
                    ]
                }
            )
            
            command_id = ssm_response['Command']['CommandId']
            
            # コマンド実行完了を待つ（最大10秒）
            for i in range(10):
                time.sleep(1)
                try:
                    result = ssm.get_command_invocation(
                        CommandId=command_id,
                        InstanceId=instance_id
                    )
                    
                    if result['Status'] in ['Success', 'Failed']:
                        output = result.get('StandardOutputContent', '').strip()
                        
                        if 'MINECRAFT_READY' in output:
                            return {
                                'statusCode': 200,
                                'body': json.dumps({
                                    'ready': True,
                                    'state': 'running',
                                    'public_ip': public_ip,
                                    'minecraft_status': 'ready',
                                    'message': 'Minecraft server is ready'
                                })
                            }
                        elif 'MINECRAFT_STARTING' in output:
                            return {
                                'statusCode': 200,
                                'body': json.dumps({
                                    'ready': False,
                                    'state': 'running',
                                    'public_ip': public_ip,
                                    'minecraft_status': 'starting',
                                    'message': 'Minecraft server is starting'
                                })
                            }
                        else:
                            return {
                                'statusCode': 200,
                                'body': json.dumps({
                                    'ready': False,
                                    'state': 'running',
                                    'public_ip': public_ip,
                                    'minecraft_status': 'not_started',
                                    'message': 'Minecraft server not started yet'
                                })
                            }
                        break
                except ssm.exceptions.InvocationDoesNotExist:
                    continue
            
            # タイムアウト
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'ready': False,
                    'state': 'running',
                    'public_ip': public_ip,
                    'minecraft_status': 'unknown',
                    'message': 'Could not determine Minecraft status'
                })
            }
            
        except Exception as ssm_error:
            # SSMが使えない場合はEC2の状態のみ返す
            print(f'SSM check failed: {ssm_error}')
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'ready': False,
                    'state': state,
                    'public_ip': public_ip,
                    'minecraft_status': 'unknown',
                    'message': 'SSM check failed, EC2 is running but Minecraft status unknown'
                })
            }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'ready': False,
                'error': str(e)
            })
        }
