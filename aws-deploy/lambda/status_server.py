import boto3
import os
import json
import time

def lambda_handler(event, context):
    instance_id = os.environ['INSTANCE_ID']
    region = os.environ.get('AWS_REGION', 'ap-northeast-1')
    
    ec2 = boto3.client('ec2', region_name=region)
    ssm = boto3.client('ssm', region_name=region)
    
    try:
        # インスタンスの状態を確認
        response = ec2.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        
        state = instance['State']['Name']
        public_ip = instance.get('PublicIpAddress', 'N/A')
        
        # プレイヤー数を取得（サーバーが起動中の場合のみ）
        player_count = None
        max_players = 20
        
        if state == 'running':
            try:
                # SSM経由でauto-shutdownログからプレイヤー数を取得
                ssm_response = ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName='AWS-RunShellScript',
                    Parameters={
                        'commands': [
                            'tail -n 100 /var/log/minecraft-autoshutdown.log | grep "Player count changed" | tail -1 | grep -oP "current: \\K[^)]*" || echo "0"'
                        ]
                    },
                    TimeoutSeconds=30
                )
                
                command_id = ssm_response['Command']['CommandId']
                
                # コマンド実行完了を待つ（最大3秒）
                for _ in range(3):
                    time.sleep(1)
                    output_response = ssm.get_command_invocation(
                        CommandId=command_id,
                        InstanceId=instance_id
                    )
                    
                    if output_response['Status'] in ['Success', 'Failed']:
                        if output_response['Status'] == 'Success':
                            output = output_response['StandardOutputContent'].strip()
                            if output:
                                # "player1, player2" または "none" または "0"
                                if output == 'none' or output == '0':
                                    player_count = 0
                                else:
                                    # カンマで分割してプレイヤー数をカウント
                                    player_count = len([p for p in output.split(',') if p.strip()])
                        break
            except Exception as e:
                print(f"プレイヤー数取得エラー: {e}")
                # エラーが発生してもステータスは返す
        
        # 状態に応じたメッセージを作成
        if state == 'running':
            status_emoji = '🟢'
            status_text = '起動中'
            if player_count is not None:
                message = f'{status_emoji} **サーバー状態**: {status_text}\n\n**サーバーアドレス**: `{public_ip}:25565`\n**プレイヤー**: {player_count}/{max_players}\n\nサーバーに接続できます。'
            else:
                message = f'{status_emoji} **サーバー状態**: {status_text}\n\n**サーバーアドレス**: `{public_ip}:25565`\n\nサーバーに接続できます。'
        elif state == 'stopped':
            status_emoji = '🔴'
            status_text = '停止中'
            message = f'{status_emoji} **サーバー状態**: {status_text}\n\n`/start` コマンドでサーバーを起動してください。'
        elif state == 'stopping':
            status_emoji = '🟡'
            status_text = '停止処理中'
            message = f'{status_emoji} **サーバー状態**: {status_text}\n\nサーバーは現在停止処理中です。しばらくお待ちください。'
        elif state == 'pending':
            status_emoji = '🟡'
            status_text = '起動処理中'
            message = f'{status_emoji} **サーバー状態**: {status_text}\n\nサーバーは現在起動処理中です。しばらくお待ちください。'
        else:
            status_emoji = '⚪'
            status_text = state
            message = f'{status_emoji} **サーバー状態**: {status_text}'
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': message,
                'state': state,
                'public_ip': public_ip,
                'player_count': player_count,
                'max_players': max_players
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
