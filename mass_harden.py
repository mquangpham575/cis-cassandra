import subprocess
import time

def run_az_cmd(vm_name, cmd):
    rg = "rg-cis-cassandra"
    print(f"[{vm_name}] Running: {cmd}")
    az_cmd = [
        "az", "vm", "run-command", "invoke",
        "-g", rg,
        "-n", vm_name,
        "--command-id", "RunShellScript",
        "--scripts", cmd
    ]
    return subprocess.Popen(az_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def main():
    nodes = ["cis-cassandra-node1", "cis-cassandra-node2", "cis-cassandra-node3"]
    processes = []
    
    print("Initiating Section 3 Hardening on all nodes in parallel...")
    for node in nodes:
        # We run the toolkit already deployed at /opt/cis
        p = run_az_cmd(node, "sudo bash /opt/cis/cis-tool.sh harden 3")
        processes.append((node, p))
    
    print("Waiting for completion (this may take a minute)...")
    for node, p in processes:
        stdout, stderr = p.communicate()
        if p.returncode == 0:
            print(f"[{node}] Success")
            # print(stdout)
        else:
            print(f"[{node}] Failed")
            print(stderr)

if __name__ == "__main__":
    main()
