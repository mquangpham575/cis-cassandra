#!/bin/bash
cd /home/cassandra/cis-cassandra
tar -czf ../cluster_tool.tar.gz cis-tool.sh scripts
for ip in 10.0.1.11 10.0.1.12 10.0.1.13; do
  echo "Syncing to $ip..."
  scp -i ~/.ssh/cis_key -o StrictHostKeyChecking=no ../cluster_tool.tar.gz "cassandra@$ip:~/"
  ssh -i ~/.ssh/cis_key -o StrictHostKeyChecking=no "cassandra@$ip" "mkdir -p ~/cis-tool && tar -xzf ~/cluster_tool.tar.gz -C ~/cis-tool"
done
