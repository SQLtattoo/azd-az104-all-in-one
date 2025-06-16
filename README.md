# AZ-104 Azure Administrator Demo Environment

This repository contains infrastructure as code (Bicep) to deploy a comprehensive environment for Azure Administrator (AZ-104) training and demonstrations.

This scenario is part of the broader Azure Demo Catalog, available at [Trainer-Demo-Deploy](https://aka.ms/trainer-demo-deploy).

## Pre-deployment Steps

1. **Find your Object ID**:
   Before deploying, you must add your Azure AD Object ID to the `azure.yaml` file:
   
   ```bash
   az ad signed-in-user show --query id -o tsv
   ```
   
   Copy the output and paste it as the value for `adminObjectId` in `azure.yaml`.

2. **Verify subscription access**:
   - Ensure you have Owner or Contributor access to the subscription
   - For governance components, you need User Access Administrator to create custom roles

## Deployment Instructions

## 1. Installation 
- You need [Azure Developer CLI - AZD](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd), in case that's your first azd deployment go ahead and install it.
    - When installing AZD, the following tools will be installed on your machine as well, if not already installed:
        - [GitHub CLI](https://cli.github.com)
        - [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

## 2. Deploying the scenario in 3 steps: 

1. Create a new folder on your machine and navigate to it.
```
mkdir -p sqltattoo/azd-az104-all-in-one && cd sqltattoo/azd-az104-all-in-one 
```
2. Next, run `azd init` to initialize the deployment.
```
azd init -t sqltattoo/azd-az104-all-in-one
```
3. Last, run `azd up` to trigger an actual deployment.
```
azd up
```

## 3. Done? Remove it from your subscription
```
azd down --purge --force 
```

**Note**: check that the recovery services vault has been removed as it could be resisting if it has been used and needs to be removed manually by its removal script.

## Demo Features
Check the **[demo guide](https://github.com/SQLtattoo/azd-az104-all-in-one/blob/master/demoguide/demoguide.md)** for details on the demo scenario.

## Troubleshooting

- Key Vault deployment fails: Verify your Object ID is correct and that you have sufficient permissions
- Custom RBAC role not visible: It may take a few minutes for the role to appear in the Azure Portal
- Monitoring agent failures: Ensure VMs are fully provisioned before deploying monitoring
