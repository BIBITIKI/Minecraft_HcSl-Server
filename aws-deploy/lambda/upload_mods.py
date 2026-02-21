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
        # リクエストボディからMODファイル情報を取得
        if event.get('body'):
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
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
        
        command_id = response['Command']['CommandId']
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'message': f'{len(uploaded_files)}個のMODファイルをアップロードしました。サーバーを再起動しています...',
                'uploaded_files': uploaded_files,
                'command_id': command_id
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
