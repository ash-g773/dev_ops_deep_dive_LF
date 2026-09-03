# My Terraform Notes

## From Session 1 — copy these across from my-azure-details.md

| What | Value |
|---|---|
| Subscription ID | |
| Tenant ID | |
| **Tenant domain** | e.g. `jbloggs.onmicrosoft.com` |
| My storage prefix | e.g. `stjbloggs` |

**The tenant domain matters today.** When we create an Azure AD user,
its `user_principal_name` MUST be on a domain your tenant owns.
Using someone else's will fail.

## Service Principal for Terraform

Created today. These become the four ARM_ environment variables.

| Returned by az | Terraform calls it | Environment variable | Value |
|---|---|---|---|
| `appId` | Client ID | `ARM_CLIENT_ID` | |
| `password` | Client Secret | `ARM_CLIENT_SECRET` | **never commit** |
| `tenant` | Tenant ID | `ARM_TENANT_ID` | |
| *(from az account show)* | Subscription ID | `ARM_SUBSCRIPTION_ID` | |

## The three states — in my own words

| State | What it is |
|---|---|
| Desired | |
| Known | |
| Actual | |