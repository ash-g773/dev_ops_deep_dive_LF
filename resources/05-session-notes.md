# Session 5 Notes

## Carried forward

| What | Value |
|---|---|
| Subscription ID | |
| Tenant domain | |
| My storage prefix | e.g. `stjbloggs` |
| My public IP (`curl ifconfig.me`) | needed for the SSH rule |

## SSH key

| What | Value |
|---|---|
| Key name | e.g. `default-vm-ssh` |
| Private key path | `~/azure/azure_ssh_keys/default-vm-ssh.pem` |
| Public key path | `~/azure/azure_ssh_keys/default-vm-ssh.pub` |
| Permissions checked? | `ls -l` should show `-r--------` |

## Remote backend (built this afternoon)

| What | Value |
|---|---|
| Backend resource group | |
| Backend storage account | |
| Container name | `tfstate` |
| My state key | e.g. `dev/session5/users/terraform.tfstate` |

## What a VM needs around it — in my own words

| Resource | Why it's needed |
|---|---|
| Resource group | |
| Virtual network | |
| Subnet | |
| Public IP | |
| Network interface (NIC) | |
| Network security group | |