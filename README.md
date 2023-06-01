# Azure DevOps pipeline examples

A collection of Azure DevOps pipeline template tasks, jobs and stages and example application of those templates.

## Tasks

_example usage of these tasks can be found within the jobs or stages folder_

- auth pipelines
  - uses az login and az logout to control 
- build and test a dot net core application
  - would be useful in a PR pipeline to test an application is passing prior to merging in main. _Learnt this at an Microsoft OpenHack event_.
- create a DevOps work item
  - WIP - _Learnt this at an Microsoft OpenHack event_.
- deploy a Terraform module
  - Runs __setup.sh__ to setup the environment being deployed before running init, plan and apply against a Terraform root module.
- get hosted ip agent
  - uses https://ifconfig.me to determine the hosted agents IP address
- install figlet
  - Figlet is used to display ASCII art - a bash [function](https://github.com/heathen1878/Terraform/blob/main/scripts/functions/apps.sh) uses it
- load modules
  - load numerous bash functions within the Terraform scripts folder
- set Key Vault Acl
  - Sets the Key Vault firewall Acl using the output of the get hosted agent ip task.
- set Storage Account Acl
  - Sets the Storage Account firewall Acl using the output of the get hosted agent ip task.
- terraform installer
  - installs Terraform - requires the Terraform [marketplace extension](https://marketplace.visualstudio.com/items?itemName=charleszipp.azure-pipelines-tasks-terraform) or [Microsoft's version](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks&targetId=1b31a8fc-9a57-433b-ac74-31ac7ad5f216&utm_source=vstsproduct&utm_medium=ExtHubManageList)
- validate module
  - - Runs __setup.sh__ to setup the environment being vaildated before running init, plan and apply against the config Terraform root module or init and plan against any other module

## Jobs

- validation
  - validates a given number of Terraform root modules by default config and web_app_behind_cloudflare

- deployment
  - deploys a given number of Terraform root modules by default config and web_app_behind_cloudflare

## Stages

- full deployment
  - performs a full Terraform deployment across multiple environment. See example below

```yaml
trigger:
  none

variables:
- template: ../../../global_variables.yml
- template: variables.yml

pool:
  vmImage: ubuntu-latest

stages:
- template: ../../../templates/stages/full_deploy.yml
  parameters:
    stage_name: "Deploy_to_Development"
    stage_display_name: "Deploy to Development"
    key_vault: $(key_vault)
    storage_account: $(storage_account)
    terraform_version: ${{ variables.terraform_version }}
    namespace: ${{ variables.namespace }}
    environment: dev
    location: ${{ variables.location }}
    automation_user: $(automation_user)
    automation_password: $(automation_password)
    tenant: $(tenant)

- template: ../../../templates/stages/full_deploy.yml
  parameters:
    stage_name: "Deploy_to_Test"
    stage_display_name: "Deploy to Test"
    key_vault: $(key_vault)
    storage_account: $(storage_account)
    terraform_version: ${{ variables.terraform_version }}
    namespace: ${{ variables.namespace }}
    environment: tst
    location: ${{ variables.location }}
    automation_user: $(automation_user)
    automation_password: $(automation_password)
    tenant: $(tenant)

- template: ../../../templates/stages/full_deploy.yml
  parameters:
    stage_name: "Deploy_to_Staging"
    stage_display_name: "Deploy to Staging"
    key_vault: $(key_vault)
    storage_account: $(storage_account)
    terraform_version: ${{ variables.terraform_version }}
    namespace: ${{ variables.namespace }}
    environment: stg
    location: ${{ variables.location }}
    automation_user: $(automation_user)
    automation_password: $(automation_password)
    tenant: $(tenant)

- template: ../../../templates/stages/full_deploy.yml
  parameters:
    stage_name: "Deploy_to_Production"
    stage_display_name: "Deploy to Production"
    key_vault: $(key_vault)
    storage_account: $(storage_account)
    terraform_version: ${{ variables.terraform_version }}
    namespace: ${{ variables.namespace }}
    environment: prd
    location: ${{ variables.location }}
    automation_user: $(automation_user)
    automation_password: $(automation_password)
    tenant: $(tenant)
```

TODO:

- [ ] Workout how to use the replace function with parameters, so I only have to pass stage_name