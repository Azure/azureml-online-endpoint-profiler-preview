## IMPORTANT: this file and accompanying assets are the source for snippets in https://docs.microsoft.com/azure/machine-learning! 
## Please reach out to the Azure ML docs & samples team before before editing for the first time.

## Preparation Steps:
## 1. az upgrade -y
## 2. az extension remove -n ml
## 3. az extension remove -n azure-cli-ml
## 4. az extension add -n ml
## 5. az login
## 6. az account set --subscription "<YOUR_SUBSCRIPTION>"
## 7. az configure --defaults group=<RESOURCE_GROUP> workspace=<WORKSPACE_NAME>
set -x

# <set_variables>
export ENDPOINT_NAME="${ENDPOINT_NAME}"
export DEPLOYMENT_NAME="${DEPLOYMENT_NAME}"
export SKU_CONNECTION_PAIR=${SKU_CONNECTION_PAIR}
export PROFILING_TOOL=wrk # allowed values: wrk, wrk2 and labench
export PROFILER_COMPUTE_NAME="${PROFILER_COMPUTE_NAME}" # the compute name for hosting the profiler
export CONNECTIONS=`echo $SKU_CONNECTION_PAIR | awk -F: '{print $2}'` # for wrk and wrk2 only, no. of connections for the profiling tool, default value is set to be the same as the no. of workers, or 1 if no. of workers is not set
# </set_variables>

# <create_profiling_job_yaml_file>
# please specify environment variable "IDENTITY_ACCESS_TOKEN" when working with ml compute with no appropriate MSI attached
sed \
  -e "s/<% ENDPOINT_NAME %>/$ENDPOINT_NAME/g" \
  -e "s/<% COMPUTE_NAME %>/$PROFILER_COMPUTE_NAME/g" \
  -e "s/<% SKU_CONNECTION_PAIR %>/$SKU_CONNECTION_PAIR/g" \
  profiling/profiling_job_tmpl.yml > ${ENDPOINT_NAME}_profiling_job.yml

sed \
  -e "s/<% ENDPOINT_NAME %>/$ENDPOINT_NAME/g" \
  -e "s/<% DEPLOYMENT_NAME %>/$DEPLOYMENT_NAME/g" \
  -e "s/<% PROFILING_TOOL %>/$PROFILING_TOOL/g" \
  -e "s/<% CONNECTIONS %>/$CONNECTIONS/g" \
  profiling/config_tmp.json > profiling/config.json
# </create_profiling_job_yaml_file>

# <upload_payload_file_and_config_file_to_default_blob_datastore>
default_datastore_info=`az ml datastore show --name workspaceblobstore -o json`
account_name=`echo $default_datastore_info | jq '.account_name' | sed "s/\"//g"`
container_name=`echo $default_datastore_info | jq '.container_name' | sed "s/\"//g"`
connection_string=`az storage account show-connection-string --name $account_name -o tsv`
az storage blob upload --container-name $container_name/profiling_payloads --name ${ENDPOINT_NAME}_payload.txt --file profiling/payload.txt --connection-string $connection_string
az storage blob upload --container-name $container_name/profiling_configs --name ${ENDPOINT_NAME}_config.json --file profiling/config.json --connection-string $connection_string
# </upload_payload_file_and_config_file_to_default_blob_datastore>

# <create_profiling_job>
run_id=$(az ml job create -f ${ENDPOINT_NAME}_profiling_job.yml --query name -o tsv)
# </create_profiling_job>

# <check_job_status_in_studio>
az ml job show -n $run_id --web
# </check_job_status_in_studio>

# <stream_job_logs_to_console>
az ml job stream -n $run_id
sleep 10
# </stream_job_logs_to_console>

# <get_job_report>
az ml job download --name $run_id --download-path report_$run_id
echo "Job result has been downloaded to dir report_$run_id"
# </get_job_report>