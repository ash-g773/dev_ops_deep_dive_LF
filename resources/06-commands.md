# kubectl Reference — Session 6

## Connecting

    az aks get-credentials --resource-group <rg> --name <cluster>
                          Fetch credentials and write them to ~/.kube/config
    kubectl version       Client version, and server version if connected

## Looking at things

    kubectl get all               Everything in the current namespace
    kubectl get pods              Just the pods
    kubectl get pods -o wide      ...with extra columns (IP, node)
    kubectl get pods --show-labels    ...with their labels
    kubectl get deployment        The things managing releases
    kubectl get replicaset        (or 'rs') The things maintaining pod count
    kubectl get service           (or 'svc') The stable network endpoints
    kubectl get events --sort-by=.metadata.creationTimestamp
                                  What the cluster has been doing, oldest first

## Digging deeper

    kubectl describe pod <name>       Full detail on one pod
    kubectl logs <pod-name>           That pod's application output
    kubectl explain <kind>            Built-in docs for any object type
    kubectl get pods -w               WATCH — stream changes live (Ctrl+C to stop)

## Making things happen (imperative — fine for learning)

    kubectl create deployment <name> --image=<image>
    kubectl expose deployment <name> --type=LoadBalancer --port=8080
    kubectl scale deployment <name> --replicas=3
    kubectl set image deployment <name> <container>=<image>:<tag>
    kubectl delete pod <name>

## Making things happen (declarative — what you'd actually use)

    kubectl get deployment <name> -o yaml > deployment.yaml
                                  Generate YAML from what's running
    kubectl apply -f <file>       Make reality match this file
    kubectl diff -f <file>        What WOULD change (like terraform plan)
    kubectl apply -f <file> --dry-run=client    Validate without applying
    kubectl delete -f <file>      Remove what this file describes

## Rollouts

    kubectl rollout status deployment/<name>    Wait until the update completes
    kubectl rollout history deployment/<name>   Previous revisions
    kubectl rollout undo deployment/<name>      Roll back to the previous one