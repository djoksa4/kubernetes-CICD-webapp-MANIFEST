# ARGOCD SETUP

# Create namespace
kubectl create namespace argocd

# Apply ArgoCD manifest installation file
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify ArgoCD resources are coming up
kubectl get all -n argocd

# Get the initial admin secret for UI login
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forwarding to connect to the API server through UI without exposing the service
# argocd-server listens on 443, we forward to 8080 instance port from ANY address (not just local)
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443






