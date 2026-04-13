import subprocess
import os

def deploy():
    rg = "rg-cis-cassandra"
    vm = "cis-cassandra-node1"
    
    with open("scripts.tar.gz.b64", "r") as f:
        b64_data = f.read().strip()
    
    # We'll use a multi-step approach to avoid command line length limits if necessary
    # But for a small tarball, one shot might work.
    
    remote_cmd = f"""
echo '{b64_data}' > /tmp/scripts.tar.gz.b64
base64 -d /tmp/scripts.tar.gz.b64 > /tmp/scripts.tar.gz
tar -xzf /tmp/scripts.tar.gz -C /tmp
sudo mkdir -p /opt/cis
sudo cp /tmp/scripts/cis-tool.sh /opt/cis/
sudo cp -r /tmp/scripts/lib /opt/cis/
sudo chmod +x /opt/cis/cis-tool.sh
sudo find /opt/cis -type f -name "*.sh" -exec sed -i 's/\\r$//' {{}} +
echo "Deployment successful"
"""
    
    print(f"Deploying to {vm}...")
    cmd = [
        "az", "vm", "run-command", "invoke",
        "-g", rg,
        "-n", vm,
        "--command-id", "RunShellScript",
        "--scripts", remote_cmd
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print("Success!")
        print(result.stdout)
    else:
        print("Error!")
        print(result.stderr)

if __name__ == "__main__":
    deploy()
