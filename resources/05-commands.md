# Command Reference — Session 5

## Terraform (revision from Part 1)

    terraform init          Download providers for THIS folder
    terraform validate      Check syntax without calling Azure
    terraform plan          What WOULD change
    terraform apply         Make it happen
    terraform destroy       Delete everything this project manages
    terraform console       Interactive REPL
    terraform graph         Print the dependency graph (DOT format)

## New today

    terraform init -reconfigure     Re-init after changing the backend
    terraform output -raw NAME      Print one output with no quotes
    terraform state list            Every resource being managed

## SSH

    chmod 400 key.pem                       Lock down a private key (REQUIRED)
    ssh -i key.pem azureuser@<public-ip>    Connect to a VM
    ssh-keygen -y -f key.pem > key.pub      Derive the public key from a private one

## Azure CLI

    az account show --query id -o tsv       Subscription ID
    az resource list -o table               Everything you own
    az group list -o table                  Your resource groups
    curl ifconfig.me                        Your own public IP address

## Where things live on a Linux VM (from Session 2)

    /var/www/html      Web server content — Apache serves from here
    /etc               Configuration files
    /var/log           Logs