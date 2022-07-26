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

# <set_variables>
export ENDPOINT_NAME="${ENDPOINT_NAME}"
export DEPLOYMENT_NAME="${DEPLOYMENT_NAME}"
export SKU_CONNECTION_PAIR=${SKU_CONNECTION_PAIR}
export PROFILING_TOOL=wrk # allowed values: wrk, wrk2 and labench
export PROFILER_COMPUTE_NAME="${PROFILER_COMPUTE_NAME}" # the compute name for hosting the profiler
export DURATION="" # time for running the profiling tool (duration for each wrk call or labench call), default value is 300s
export CONNECTIONS=`echo $SKU_CONNECTION_PAIR | awk -F: '{print $2}'` # for wrk and wrk2 only, no. of connections for the profiling tool, default value is set to be the same as the no. of workers, or 1 if no. of workers is not set
export THREAD="" # for wrk and wrk2 only, no. of threads allocated for the profiling tool, default value is 1
export TARGET_RPS="" # for labench and wrk2 only, target rps for the profiling tool, default value is 50
export CLIENTS="" # for labench only, no. of clients for the profiling tool, default value is set to be the same as the no. of workers, or 1 if no. of workers is not set
export TIMEOUT="" # for labench only, timeout for each request, default value is 10s
# </set_variables>

# <upload_payload_file_to_default_blob_datastore>
default_datastore_info=`az ml datastore show --name workspaceblobstore -o json`
account_name=`echo $default_datastore_info | jq '.account_name' | sed "s/\"//g"`
container_name=`echo $default_datastore_info | jq '.container_name' | sed "s/\"//g"`
connection_string=`az storage account show-connection-string --name $account_name -o tsv`
az storage blob upload --container-name $container_name/profiling_payloads --name ${ENDPOINT_NAME}_payload.txt --file profiling/payload.txt --connection-string $connection_string
# </upload_payload_file_to_default_blob_datastore>

# <create_profiling_job_yaml_file>
# please specify environment variable "IDENTITY_ACCESS_TOKEN" when working with ml compute with no appropriate MSI attached
sed \
  -e "s/<% ENDPOINT_NAME %>/$ENDPOINT_NAME/g" \
  -e "s/<% DEPLOYMENT_NAME %>/$DEPLOYMENT_NAME/g" \
  -e "s/<% PROFILING_TOOL %>/$PROFILING_TOOL/g" \
  -e "s/<% DURATION %>/$DURATION/g" \
  -e "s/<% CONNECTIONS %>/$CONNECTIONS/g" \
  -e "s/<% TARGET_RPS %>/$TARGET_RPS/g" \
  -e "s/<% CLIENTS %>/$CLIENTS/g" \
  -e "s/<% TIMEOUT %>/$TIMEOUT/g" \
  -e "s/<% THREAD %>/$THREAD/g" \
  -e "s/<% COMPUTE_NAME %>/$PROFILER_COMPUTE_NAME/g" \
  -e "s/<% SKU_CONNECTION_PAIR %>/$SKU_CONNECTION_PAIR/g" \
  profiling/profiling_job_tmpl.yml > ${ENDPOINT_NAME}_profiling_job.yml
# </create_profiling_job_yaml_file>

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