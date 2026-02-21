import json
import boto3
import os
import base64

ssm = boto3.client('ssm', region_name='ap-northeast-1')
s3 = boto3.client('s3', region_name='ap-northeast-1')
INSTANCE_ID = os.environ.get('INSTANCE_ID', 'i-0b3b312b21a19f71b')
S3_BUCKET = os.environ.get('S3_BUCKET', 'minecraft-server-mods-temp')

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
        
        # MODファイルのアップロード
        if 'action' in params and params['action'] == 'upload_mods':
            # POSTリクエストのボディからMODファイル情報を取得
            if event.get('body'):
                body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
                mod_files = body.get('mod_files', [])
                
                if not mod_files:
                    return {
                        'statusCode': 400,
                        'body': json.dumps({
                            'success': False,
                            'message': 'mod_files パラメータが必要です'
                        })
                    }
                
                # S3にMODファイルをアップロード
                uploaded_files = []
                for mod_file in mod_files:
                    file_name = mod_file.get('name')
                    file_content_base64 = mod_file.get('content')
                    
                    if not file_name or not file_content_base64:
                        continue
                    
                    # Base64デコード
                    file_content = base64.b64decode(file_content_base64)
                    
                    # S3にアップロード
                    s3.put_object(
                        Bucket=S3_BUCKET,
                        Key=f'mods/{file_name}',
                        Body=file_content
                    )
                    
                    uploaded_files.append(file_name)
                
                if not uploaded_files:
                    return {
                        'statusCode': 400,
                        'body': json.dumps({
                            'success': False,
                            'message': 'アップロードするファイルがありません'
                        })
                    }
                
                # EC2でMODファイルをダウンロード
                download_command = f"""
cd /home/ubuntu/minecraft
sudo systemctl stop minecraft
mkdir -p mods_backup
if [ -d mods ] && [ "$(ls -A mods 2>/dev/null)" ]; then
    mv mods/*.jar mods_backup/ 2>/dev/null || true
fi
aws s3 sync s3://{S3_BUCKET}/mods/ mods/ --region ap-northeast-1
sudo chown -R ubuntu:ubuntu mods
sudo systemctl start minecraft
echo "MOD files updated: {', '.join(uploaded_files)}"
"""
                
                response = ssm.send_command(
                    InstanceIds=[INSTANCE_ID],
                    DocumentName='AWS-RunShellScript',
                    Parameters={'commands': [download_command]}
                )
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'success': True,
                        'message': f'{len(uploaded_files)}個のMODファイルをアップロードしました。サーバーを再起動しています...',
                        'uploaded_files': uploaded_files,
                        'command_id': response['Command']['CommandId']
                    })
                }
        
        # server.propertiesの設定を更新
        if 'server_property' in params and 'value' in params:
            property_name = params['server_property']
            property_value = params['value']
            
            # 許可されたプロパティのみ更新可能
            allowed_properties = [
                'enable-command-block',
                'difficulty',
                'gamemode',
                'max-players',
                'pvp',
                'view-distance',
                'simulation-distance'
            ]
            
            if property_name not in allowed_properties:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'message': f'プロパティ {property_name} は更新できません'
                    })
                }
            
            # SSM Run Commandでserver.propertiesを更新
            command = f"""
            cd /home/ubuntu/minecraft
            sed -i 's/^{property_name}=.*/{property_name}={property_value}/' server.properties
            sudo systemctl restart minecraft
            """
            
            response = ssm.send_command(
                InstanceIds=[INSTANCE_ID],
                DocumentName='AWS-RunShellScript',
                Parameters={'commands': [command]}
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': f'{property_name}を{property_value}に設定しました。サーバーを再起動しています...',
                    'command_id': response['Command']['CommandId']
                })
            }
        
        # 自動停止時間の設定を更新
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
