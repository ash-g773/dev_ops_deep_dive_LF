# Session 6 Notes

## My cluster

| What | Value |
|---|---|
| Resource group | |
| Cluster name | |
| Region | |
| Kubernetes version | |
| Node pool VM size | |
| Node count | |
| CPU allocatable vs advertised | e.g. "2 vCPU advertised, 1.9 allocatable" |

## Every Kubernetes YAML has four top-level keys

| Key | What it holds |
|---|---|
| `apiVersion` | |
| `kind` | |
| `metadata` | |
| `spec` | |

And a fifth, `status`, which Kubernetes fills in — never you.

## Teardown checklist — BEFORE I LEAVE

- [ ] `kubectl delete service <name>` (releases the Azure load balancer)
- [ ] `az group delete --name <my-rg> --yes --no-wait`
- [ ] `az group list -o table` shows NO `MC_...` group left behind