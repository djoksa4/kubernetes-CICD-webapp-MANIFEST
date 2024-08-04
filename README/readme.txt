0. Pipeline overview:

    - GitHub repo contains source code (JAVA), JAVA tests, Dockerfile, pom.xml file, SonarCloud config file and  GitHub Actions YAML workflow.
    - GitHub Actions pipelines runs on every push to master (selected paths).
    - pipeline will:
		- checkout the code.
		- run static code analysis using SonarCloud.
		- run unit tests present in the repo (Maven).
		- build a WAR file from the source code (Maven).
		- build a Docker image and tag it.
		- scan the Docker image (Trivy).
		- push the Docker image to DockerHub.
		- update the Helm manifest repo to use the tag of the newly generated image.

1. Created and configured demo environment on AWS using Terraform:

    - Network (VPC, public subnet, IGW, Route Table) setup.

    - EC2 instances to act as a k8s CONTROLPLANE and k8s WORKERNODE.
	- CONTROLPLANE Security group:
		- ingress port 22 TCP for ssh access.
		- ingress port 8080 TCP for ArgoCD UI access.
		- ingress port 6443 TCP for k8s API server requests.
		- ingress range 2379-2380 TCP for k8s etcd requests.
		- ingress range 10250-10259 TCP for k8s kubelet, kube-scheduler and kube-controler requests.
		- ingress range 6783-6784 UDP for Weave Net requests.
		- ingress port 6783 TCP for Weave Net requests.
		- egress for all outbound traffic (internet).
	- WORKERNODE Security group:
		- ingress port 22 TCP for ssh access.
		- ingress port 10250 TCP for kubelet API requests.
		- ingress range 30000-32767 TCP for NodePort services (app will be accessed through NodePort).
		- ingress range 6783-6784 UDP for Weave Net requests.
		- ingress port 6783 TCP for Weave Net request.
		- egress for all outbound traffic (internet).
	
	- configured Kuebrnetes cluster (CONTROLPLANE and WORKERNODE) - 'k8s_fedora_setup.sh'.
	- configured ArgoCD - 'k8s_argocd_setup.sh'.

