# Azure ML Online Endpoints model profiling

This repo shows the more extensive capabilities of using [GitHub Actions](https://github.com/features/actions) with [Azure Machine Learning](https://docs.microsoft.com/en-us/azure/machine-learning/) to profile models for online inferencing using [Online Endpoints](https://docs.microsoft.com/en-us/azure/machine-learning/concept-endpoints).

Learn more about [how to use online endpoints for online infernecing](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-deploy-managed-online-endpoints).

# Getting started

### 1. Prerequisites

The following prerequisites are required to make this repository work:
- Azure subscription
- Owner of the Azure subscription
- Access to [GitHub Actions](https://github.com/features/actions)

If you don’t have an Azure subscription, create a free account before you begin. Try the [free or paid version of Azure Machine Learning](https://aka.ms/AMLFree) today.

### 2. Create repository

Fork this repo.

### 3. Setting up the required secrets

A service principal needs to be generated for authentication and getting access to your Azure subscription. We suggest adding a service principal with contributor rights to a new resource group or to the one where you have deployed your existing Azure Machine Learning workspace. Just go to the Azure Portal to find the details of your resource group or workspace. Then start the Cloud CLI or install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) on your computer and execute the following command to generate the required credentials:

```sh
# Replace {service-principal-name}, {subscription-id} and {resource-group} with your 
# Azure subscription id and resource group name and any name for your service principle
az ad sp create-for-rbac --name {service-principal-name} \
                         --role contributor \
                         --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group}
```

This will generate the following JSON output:

```sh
{
  "clientId": "<GUID>",
  "clientSecret": "<GUID>",
  "subscriptionId": "<GUID>",
  "tenantId": "<GUID>",
  (...)
}
```

Add this JSON output as [a secret](https://help.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets) with the name `AZURE_CREDENTIALS` in your GitHub repository:

<p align="center">
  <img src="docs/images/secrets.png" alt="GitHub Template repository" width="700"/>
</p>

To do so, click on the Settings tab in your repository, then click on Secrets and finally add the new secret with the name `AZURE_CREDENTIALS` to your repository.

Please follow [this link](https://help.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets) for more details. 

### 4. Define your workspace parameters

This example uses secrets to store your workspace parameters, please add `SUBSCRIPTION_ID`, `AML_WORKSPACE` and `RESOURCE_GROUP` as secrets in your GitHub repository.

### 5. Modify the code

Now you can start modifying the code in the <a href="/code">`code` folder</a>, so that your model and not the provided sample model gets deployed and profiled on Azure. Where required, modify the environment yaml so that the environment will have the correct packages installed in the conda environment for your inferencing.

### 6. Kickoff auto profile with multiple SKUs

Run the `deploy` GitHub action. It will kick off the model deployment. After it's completed, `profile` action will automatically started.