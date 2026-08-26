# Azure CLI — Session 1 Reference

Everything we run today, with what it does.

## Getting started

    az --version          Check the CLI is installed
    az login              Sign in (opens a browser)
    az account show       Show the subscription you're currently working in

## Reading the output of `az account show`

It returns JSON. The fields that matter:

    id                    Your SUBSCRIPTION ID  <- write this down
    name                  The subscription's display name
    tenantId              Your TENANT ID        <- write this down
    tenantDefaultDomain   Your TENANT DOMAIN    <- write this down
    user.name             Who you're signed in as
    state                 Is the subscription active

## Pulling out a single value

    az account show --query id -o tsv

    --query   picks one field out of the JSON
    -o tsv    prints the bare value, with no quotes or brackets
    -o table  prints a readable table instead of JSON

## Resource groups

    az group list -o table                              List them
    az group create --name <name> --location uksouth    Create one
    az group delete --name <name> --yes                 Delete one (and everything in it)

## Resources

    az resource list -o table                           Everything you own
    az resource list --resource-group <name> -o table    Everything in one group

## Storage accounts

    az storage account create \
      --name <globally-unique-name> \
      --resource-group <rg-name> \
      --location uksouth \
      --sku Standard_LRS

Name rules: lowercase letters and numbers only, 3-24 characters,
and unique across the whole of Azure.

## Identity

    az ad signed-in-user show                Your own user object
    az ad sp list --show-mine -o table       Service Principals you created

    az ad sp create-for-rbac \
      --name "example-automation-identity" \
      --role "Reader" \
      --scopes "/subscriptions/<your-subscription-id>"

    az role assignment list --assignee <upn-or-appId> -o table
