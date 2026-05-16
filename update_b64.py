import base64

with open('scripts.tar.gz.b64', 'r') as f:
    b64_data = f.read().replace('\n', '').replace('\r', '')

with open('remote_deploy.sh', 'r') as f:
    lines = f.readlines()

with open('remote_deploy.sh', 'w') as f:
    for line in lines:
        if line.startswith('B64_DATA='):
            f.write(f'B64_DATA="{b64_data}"\n')
        else:
            f.write(line)
