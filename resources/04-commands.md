# Terraform CLI Reference — Session 4

## The core loop

    terraform init        Download the providers this project needs.
                          Run once per project, and again if you add a provider.

    terraform plan        Work out what WOULD change. Changes nothing.
    terraform apply       Actually make the changes. Asks you to type 'yes'.
    terraform destroy     Delete everything this project manages.

## Checking your work

    terraform validate    Is the config syntactically valid? Doesn't call Azure.
    terraform fmt         Auto-format all .tf files to the standard style.
    terraform show        Print the current state in readable form.
    terraform console     Interactive REPL for querying your config and state.

## Useful flags

    terraform plan -out=tfplan        Save the plan to a file
    terraform apply "tfplan"          Apply exactly that saved plan (no prompt)
    terraform apply -refresh=false    Skip asking Azure what really exists
    terraform apply -target=TYPE.NAME Only touch one resource
    terraform apply -var="name=value" Set a variable on the command line

## Inspecting state (safer than opening the JSON)

    terraform state list              Every resource Terraform manages
    terraform state show ADDRESS      All attributes of one resource

## Referring to things

    <resource_type>.<internal_name>              a resource
    <resource_type>.<internal_name>.<attribute>  one of its attributes
    var.<variable_name>                          a variable
    data.<type>.<name>                           a data source