# ===================================================================================
# KUBEADM / RED-HAT BASED DISTRO / CONTAINERD / WEAVE NET
# ===================================================================================

:'
Summary:
	- REQUIRED PORTS
	- INITIAL SETUP (both CONTROLPLANE and WORKERNODES)
	- CONTAINER RUNTIME INTERFACE (CRI) SETUP (both CONTROLPLANE and WORKERNODES)
	- INSTALL kubeadm, kubelet AND kubectl (both CONTROLPLANE and WORKERNODES)
	- INITIALIZE THE CLUSTER (on CONTROLPLANE)
	- FIX CLUSTER - BY FIXING CONTAINERD (on CONTROLPLANE and WORKERNODES)
	- DEPLOY CNI - WEAVE NET (on CONTROLPLANE)
	- JOIN WORKER NODES (on WORKERNODES)
	- LOGS AND TESTING (on CONTROLPLANE)
'
	
# ===================================================================================
# REQUIRED PORTS
# ===================================================================================

:'
CONTROLPLANE
	Inbound:
		TCP/22 (ssh access)
		TCP/6443 (K8s API server)
		TCP/2379-2380 (etcd server client API)
		TCP/10250-10259 (kubelet, kube-scheduler, kube-controller)
		UDP/6783-6784 (Weave Net)
		TCP/6783 (Weave Net)
	Outbound:
		all

WORKERNODE
	Inbound:
		TCP/22 (ssh access)
		TCP/10250 (Kubelet API)
		TCP/30000-32767 (NodePort services)
		UDP/6783-6784 (Weave Net)
		TCP/6783 (Weave Net)
	Outbound:
		all
'

# ===================================================================================
# INITIAL SETUP (both CONTROLPLANE and WORKERNODES)
# ===================================================================================

# Disable swap (required by Kubernetes)
sudo swapoff -a

# Add ip to hostname mapping
echo '10.0.0.70 controlplane' | sudo tee -a /etc/hosts > /dev/null
echo '10.0.0.71 workernode01' | sudo tee -a /etc/hosts > /dev/null
echo '10.0.0.72 workernode02' | sudo tee -a /etc/hosts > /dev/null


# ===================================================================================
# CONTAINER RUNTIME INTERFACE (CRI) SETUP (both CONTROLPLANE and WORKERNODES)
# ===================================================================================

# Create containerd config file with list of necessary modules that need to be loaded with containerd
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load kernel modules (for filesystem overlay and Kubernetes networking CNI plugins)
sudo modprobe overlay
sudo modprobe br_netfilter

# Create config file for kubernetes-cri file (changed to k8s.conf)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params (sysctl params required by setup, persist across reboots)
sudo sysctl --system

# Verify that the br_netfilter, overlay modules are loaded
lsmod | grep br_netfilter
lsmod | grep overlay

# Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system variables
# are set to 1 in your sysctl config
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# Update packages list
sudo dnf makecache

# Install containerd
sudo dnf install -y containerd

# Create a default config file at default location
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

# Verify status of containerd is active
service containerd status


# ===================================================================================
# INSTALL kubeadm, kubelet AND kubectl (both CONTROLPLANE and WORKERNODES)
# ===================================================================================

# Update packages list
sudo dnf makecache

# Download and add the GPG key for the Kubernetes package repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/pki/rpm-gpg/kubernetes-apt-keyring.gpg

# Add the Kubernetes package repository to yum repos
sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes Repository
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/kubernetes-apt-keyring.gpg
EOF

# Update packages list
sudo dnf makecache

# Install latest versions of kubelet, kubeadm and kubectl
sudo dnf install -y kubelet kubeadm kubectl

# Fixate version to prevent upgrades


# Verify kubeadm is properly installed
kubeadm version

# Confirm kubelet service is inactive because we haven’t initialised the cluster yet
sudo systemctl status kubelet


# ===================================================================================
# INITIALIZE THE CLUSTER (on CONTROLPLANE)
# ===================================================================================

# Run initialization (make sure to copy the 'kubeadm join' command from the output)
sudo kubeadm init

# When execute commands using kubectl, it looks for certificates in the config file in ~/.kube/config, but kubernetes puts the default admin config file in /etc/kubernetes/admin.conf
# Copy the files from kubernetes default location to ~/.kube/config file (and gives current user permissions)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check the status of the static pods
kubectl get pod -A

# At this point API server should respond, however it might throw a “connection refused” or “incorrect host” error


# ===================================================================================
# FIX CLUSTER - BY FIXING CONTAINERD (on CONTROLPLANE and WORKERNODES)
# ===================================================================================

# To prevent crash loop containers, apply the fix to containerd conf file
# Apply fix to address “pod sandbox changed” error (default to systemd driver in  containerd runtime which kubernetes already expects)
# Edit the containerd config file (set SystemdCgroup parameter to true)
sudo nano /etc/containerd/config.toml

# Restart containerd and kubelet services
sudo systemctl restart containerd
sudo systemctl restart kubelet

# Now the api server will always respond to kubctl commands, plus container restart counts should not increase
kubectl get pod -A


# ===================================================================================
# DEPLOY CNI - WEAVE NET (on CONTROLPLANE)
# ===================================================================================

# Apply weave net (provides networking and network policy solutions - communication between containers across different hosts, creating a virtual network overlay)
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Verify coredns pods are up and 2 new weave net pods are created
kubectl get pod -A


# ===================================================================================
# JOIN WORKER NODES (on WORKERNODES)
# ===================================================================================

# If we missed the command for joining nodes, we can generate join command again by executing this on CONTROLPLANE
kubeadm token create --print-join-command

# Execute the command on workernodes (example)
sudo kubeadm join 10.0.0.70:6443 --token 4040404040404040 --discorvery-token-ca-cert-hash sha256:4040404040404040404040404040

# Verify kube-proxy pods are running on workernodes (each should have one running) from CONTROLPLANE
kubectl get pod -A -o wide

# Verify weave net pods are running on workernodes from CONTROLPLANE
kubectl get pod -A -o wide | grep weave-net

# Verify kubelet service is now running on workernodes
service kubelet status


# ===================================================================================
# LOGS AND TESTING (on CONTROLPLANE)
# ===================================================================================

# Check weave net container logs
kubectl logs -n kube-system weave-net-mkm6d

# Run a test nginx pod
kubectl run test --image=nginx

# Check pods without -A or namespace flag (should show a pod named 'test' on one of the workernodes)
kubectl get pod -o wide
