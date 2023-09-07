#!/bin/bash

# Function to create a progress bar
progress_bar() {
    echo -ne '#####                     (25%)\r'
    sleep 1
    echo -ne '#########                 (50%)\r'
    sleep 1
    echo -ne '##############            (75%)\r'
    sleep 1
    echo -ne '###################       (100%)\r'
    echo -ne '\n'
}

# Suppress all output
exec 3>&1 1>/dev/null


# Check if sshpass is installed, if not, install it
if ! command -v sshpass &>/dev/null; then
    echo "sshpass is not installed, installing now..." 2>&1
    echo "Please wait, installing necessary components..." >&3
    sudo apt-get update 2>&1
    sudo apt-get install -y sshpass 2>&1
fi

# Ask for node1 and node2 IP addresses
read -p "Please enter Node1 IP address: " NODE1_IP >&3
read -p "Please enter Node2 IP address: " NODE2_IP >&3
echo "Please wait, installing cluster components..." >&3
# Initialize Kubernetes
kubeadm_output=$(kubeadm init --ignore-preflight-errors=all 2>&1)

# Run the command to export KUBECONFIG
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc 
export KUBECONFIG=/etc/kubernetes/admin.conf

# Apply the Calico configuration
kubectl apply -f https://raw.githubusercontent.com/kkpkishan/neuvector-cicd/main/calico.yaml 2>&1

sleep 15
# Extract the join command
join_command=$(echo "$kubeadm_output" | grep -A 1 "kubeadm join" | sed 'N;s/\\\n//')

# Function to execute commands on remote nodes using sudo
run_command_on_node() {
    sshpass -p 'student' ssh -o StrictHostKeyChecking=no ubuntu@$1  "sudo $2" 2>&1
}
# Run the join command on node1 and node4
for ip in $NODE1_IP $NODE2_IP; do
    run_command_on_node $ip "$join_command"
done

export KUBECONFIG=/etc/kubernetes/admin.conf

# Function to check if all nodes are in the Ready status
all_nodes_ready() {
  kubectl get nodes | grep -v STATUS | awk '{ if ($2 != "Ready") exit 1; }'
  return $?
}

# Loop to keep checking until all nodes are Ready
while true; do
  all_nodes_ready
  if [[ $? -eq 0 ]]; then
    echo "All nodes are in Ready status." >&3 
    break
  else
    echo "Waiting for all nodes to be in Ready status..." >&3
    sleep 5 # Wait for 5 seconds before checking again
  fi
done

echo "Run the script as root and bash install.sh. Not sh install.sh"
