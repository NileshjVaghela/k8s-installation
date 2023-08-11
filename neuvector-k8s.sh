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
read -p "Please enter Node3 IP address: " NODE3_IP >&3
read -p "Please enter Node4 IP address: " NODE4_IP >&3
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
for ip in $NODE1_IP $NODE2_IP $NODE3_IP $NODE4_IP; do
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

# Helm installation
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 2>&1
chmod 700 get_helm.sh 2>&1
./get_helm.sh 2>&1
 
# Remove the get_helm.sh file
rm get_helm.sh

echo "Please wait, installing NeuVector..." >&3

# Download the YAML file
curl -fsSL -o values.yaml https://raw.githubusercontent.com/neuvector/neuvector-helm/master/charts/core/values.yaml

# Use sed to change "enabled: false" to "enabled: true" under the containerd section
sed -i '/containerd:/,/path:/ s/enabled: false/enabled: true/' values.yaml


# Add the NeuVector Helm repository
helm repo add neuvector https://neuvector.github.io/neuvector-helm/ 2>&1

# Create the NeuVector namespace
kubectl create namespace neuvector 2>&1
kubectl label  namespace neuvector "pod-security.kubernetes.io/enforce=privileged" 2>&1

# Install NeuVector using the Helm chart with the temporary YAML file
helm install neuvector --namespace neuvector --create-namespace neuvector/core -f values.yaml 2>&1

# Remove the temporary YAML file
rm values.yaml


# Create a temporary YAML file for the NeuVector REST API service
temp_neuvector_service_yaml=$(mktemp)
cat <<EOL > $temp_neuvector_service_yaml
apiVersion: v1
kind: Service
metadata:
  name: neuvector-service-rest
  namespace: neuvector
spec:
  ports:
    - port: 10443
      name: controller
      protocol: TCP
  type: NodePort
  selector:
    app: neuvector-controller-pod
EOL


# Apply the YAML file to create the service
kubectl apply -f $temp_neuvector_service_yaml 2>&1

# Remove the temporary YAML file
rm $temp_neuvector_service_yaml


# Create a sample application
kubectl apply -f https://raw.githubusercontent.com/kkpkishan/neuvector-cicd/main/kubernetes-sample-apps-v1.yaml 2>&1


source ~/.bashrc 

# Get the NeuVector URL
NODE_PORT=$(kubectl get --namespace neuvector -o jsonpath="{.spec.ports[0].nodePort}" services neuvector-service-webui)
NODE_IP=$(kubectl get pods -n neuvector -l app=neuvector-manager-pod -o=jsonpath="{.items[*].status.hostIP}")
echo "Access NeuVector at: https://$NODE_IP:$NODE_PORT" >&3
echo "Please wait 5 minutes, as the pods may take some time to run."  >&3
echo "You can access the application using the following credentials:"  >&3
echo "Username: admin"  >&3
echo "Password: admin" >&3

sleep 1

# Get the NodePort for the REST API service
API_NODE_PORT=$(kubectl get --namespace neuvector -o jsonpath="{.spec.ports[0].nodePort}" services neuvector-service-rest) 
NODE_IP=$(kubectl get pods -n neuvector -l app=neuvector-manager-pod -o=jsonpath="{.items[*].status.hostIP}")
echo "Access API NeuVector at: https://$NODE_IP:$API_NODE_PORT"  >&3

sleep 1

# Get the NodePort for the bookinfo application service
SAMPLE_APP_NODE_PORT=$(kubectl get --namespace bookinfo -o jsonpath="{.spec.ports[0].nodePort}" services productpage)
NODE_IP=$(kubectl get pods -n bookinfo -l app=productpage -o=jsonpath="{.items[0].status.hostIP}")

# Echo the URL to access the bookinfo application
echo "Access the bookinfo application at: http://$NODE_IP:$SAMPLE_APP_NODE_PORT"  >&3

sleep 1

# Get the NodePort for the boutique  application service
SAMPLE_APP_NODE_PORT=$(kubectl get --namespace boutique  -o jsonpath="{.spec.ports[0].nodePort}" services frontend-external)
NODE_IP=$(kubectl get pods -n boutique  -l app=frontend -o=jsonpath="{.items[0].status.hostIP}")

# Echo the URL to access the boutique  application
echo "Access the boutique application at: http://$NODE_IP:$SAMPLE_APP_NODE_PORT" >&3

sleep 1

# Get the NodePort for the doks  application service
SAMPLE_APP_NODE_PORT=$(kubectl get --namespace doks  -o jsonpath="{.spec.ports[0].nodePort}" services doks-example)
NODE_IP=$(kubectl get pods -n doks  -l app=doks-example -o=jsonpath="{.items[0].status.hostIP}")

# Echo the URL to access the doks  application
echo "Access the doks application at: http://$NODE_IP:$SAMPLE_APP_NODE_PORT" >&3

sleep 1

# Get the NodePort for the game-2048  application service
SAMPLE_APP_NODE_PORT=$(kubectl get --namespace game-2048  -o jsonpath="{.spec.ports[0].nodePort}" services service-2048)
NODE_IP=$(kubectl get pods -n game-2048 -l app.kubernetes.io/name=app-2048 -o=jsonpath="{.items[0].status.hostIP}")

# Echo the URL to access the game-2048  application
echo "Access the game-2048 application at: http://$NODE_IP:$SAMPLE_APP_NODE_PORT" >&3

sleep 1

# Get the NodePort for the  podinfo  application service
SAMPLE_APP_NODE_PORT=$(kubectl get --namespace  podinfo  -o jsonpath="{.spec.ports[0].nodePort}" services frontend-podinfo)
NODE_IP=$(kubectl get pods -n  podinfo  -l app=frontend-podinfo -o=jsonpath="{.items[0].status.hostIP}")

# Echo the URL to access the  podinfo  application
echo "Access the  podinfo application at: http://$NODE_IP:$SAMPLE_APP_NODE_PORT" >&3


# Restore output and show progress bar
exec 1>&3 2>&1
echo "Progress:" >&3
progress_bar

echo "All tasks completed." >&3
