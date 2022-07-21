# Online Endpoints Model Profiler

## Overview

Inferencing machine learning models is a time and compute intensive process. It is vital to quantify the performance of model inferencing to ensure that you make the best use of compute resources and reduce cost to reach the desired performance SLA (e.g. latency, throughput).

Online Endpoints Model Profiler provides fully managed experience that makes it easy to benchmark your model performance served through [Online Endpoints](https://docs.microsoft.com/en-us/azure/machine-learning/concept-endpoints).

* Use the benchmarking tool of your choice.

* Easy to use CLI experience.
  
* Support for CI/CD MLOps pipelines to automate profiling.
  
* Thorough performance report containing latency percentiles and resource utilization metrics.

## A brief introduction on benchmarking tools

The online endpoints model profiler currently supports 4 types of benchmarking tools: wrk, wrk2, labench and mlperf

* `wrk`: wrk is a modern HTTP benchmarking tool capable of generating significant load when run on a single multi-core CPU. It combines a multithreaded design with scalable event notification systems such as epoll and kqueue. For detailed info please refer to this link: https://github.com/wg/wrk.

* `wrk2`: wrk2 is wrk modifed to produce a constant throughput load, and accurate latency details to the high 9s (i.e. can produce accuracy 99.9999% if run long enough). In addition to wrk's arguments, wrk2 takes a throughput argument (in total requests per second) via either the --rate or -R parameters (default is 1000). For detailed info please refer to this link: https://github.com/giltene/wrk2.

* `labench`: LaBench (for LAtency BENCHmark) is a tool that measures latency percentiles of HTTP GET or POST requests under very even and steady load. For detailed info please refer to this link: https://github.com/microsoft/LaBench.

* `mlperf`: MLPerf Inference is a benchmark suite for measuring how fast systems can run models in a variety of deployment scenarios.
  
  mlperf contains 3 test modes:
  
  1. `server`: User needs to provide a TARGET_RPS_LIST, and the profiler will run multiple profiling jobs, each on a target rps in the list.
  2. `searchThroughput`: The profiler will run a series of profiling jobs to find out the best rps performance while the latency is within the designated limitation. User is optional to provide one rps in this TARGET_RPS_LIST, and this rps will be used as the lower bound when searching for the best performance. If the value is not provided, the default lower bound is 1. User should also keep in mind that if the lower bound rps does not satisfy the latency limitation, the profiling job will stop immediately.
  3. `singleStream`: The profiler will run one job, within which, requests will be sent in a single thread, and each request will be sent after the response for the previous request is received.
  
## Prerequisites

* Azure subscription. If you don't have an Azure subscription, sign up to try the [free or paid version of Azure Machine Learning](https://azure.microsoft.com/free/) today.

* Azure CLI and ML extension. For more information, see [Install, set up, and use the CLI (v2) (preview)](how-to-configure-cli.md).

## Get started

Please follow this [example](https://github.com/Azure/azureml-examples/blob/xiyon/mir-profiling/cli/how-to-profile-online-endpoint.sh) and get started with the model profiling experience.

### Create an online endpoint

Follow the example in this [tutorial](https://github.com/Azure/azureml-examples/blob/main/cli/deploy-managed-online-endpoint.sh) to deploy a model using an online endpoint.

* Replace the `instance_type` in deployment yaml file with your desired Azure VM SKU. VM SKUs vary in terms of computing power, price and availability in different Azure regions.

* Tune `request_settings.max_concurrent_requests_per_instance` which defines the concurrent level. The higher this setting is, the higher throughput the endpoint gets. If this setting is set higher than the online endpoint can handle, the inference request may end up waiting in the queue and eventually results in longer end-to-end latency.

* If you plan to profile using multiple `instance_type` and `request_settings.max_concurrent_requests_per_instance`, please create one online deployment for each pair. You can attach all online deployments under the same online endpoint.

Below is a sample yaml file defines an online deployment.

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json
name: blue
endpoint_name: my-endpoint
model:
  path: ../../model-1/model/sklearn_regression_model.pkl
code_configuration:
  code: ../../model-1/onlinescoring/
  scoring_script: score.py
environment: 
  conda_file: ../../model-1/environment/conda.yml
  image: mcr.microsoft.com/azureml/openmpi3.1.2-ubuntu18.04:20210727.v1
instance_type: Standard_F2s_v2
instance_count: 1
request_settings:
  request_timeout_ms: 3000
  max_concurrent_requests_per_instance: 1024
```

### Create a compute to host the profiler

You will need a compute to host the profiler, send requests to the online endpoint and generate performance report.

* This compute is NOT the same one that you used above to deploy your model. Please choose a compute SKU with proper network bandwidth (considering the inference request payload size and profiling traffic, we'd recommend Standard_F4s_v2) in the same region as the online endpoint.

  ```bash
  az ml compute create --name $PROFILER_COMPUTE_NAME --size $PROFILER_COMPUTE_SIZE --identity-type SystemAssigned --type amlcompute
  ```

* Create proper role assignment for accessing online endpoint resources. The compute needs to have contributor role to the machine learning workspace. For more information, see [Assign Azure roles using Azure CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli).

  ```bash
  compute_info=`az ml compute show --name $PROFILER_COMPUTE_NAME --query '{"id": id, "identity_object_id": identity.principal_id}' -o json`
  workspace_resource_id=`echo $compute_info | jq -r '.id' | sed 's/\(.*\)\/computes\/.*/\1/'`
  identity_object_id=`echo $compute_info | jq -r '.identity_object_id'`
  az role assignment create --role Contributor --assignee-object-id $identity_object_id --scope $workspace_resource_id
  if [[ $? -ne 0 ]]; then echo "Failed to create role assignment for compute $PROFILER_COMPUTE_NAME" && exit 1; fi
  ```

### Create a profiling job

#### Understand a profiling job

A profiling job simulates how an online endpoint serves live requests. It produces a throughput load to the online endpoint and generates performance report.

Below is a template yaml file that defines a profiling job.

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
command: >
  python -m online_endpoints_model_profiler ${{inputs.payload}}
experiment_name: profiling-job
display_name: <% SKU_CONNECTION_PAIR %>
environment:
  image: mcr.microsoft.com/azureml/online-endpoints-model-profiler:latest
environment_variables:
  ONLINE_ENDPOINT: "<% ENDPOINT_NAME %>"
  DEPLOYMENT: "<% DEPLOYMENT_NAME %>"
  PROFILING_TOOL: "<% PROFILING_TOOL %>"
  DURATION: "<% DURATION %>"
  CONNECTIONS: "<% CONNECTIONS %>"
  TARGET_RPS: "<% TARGET_RPS %>"
  CLIENTS: "<% CLIENTS %>"
  TIMEOUT: "<% TIMEOUT %>"
  THREAD: "<% THREAD %>"
compute: "azureml:<% COMPUTE_NAME %>"
inputs:
  payload:
    type: uri_file
    path: azureml://datastores/workspaceblobstore/paths/profiling_payloads/<% ENDPOINT_NAME %>_payload.txt
```

##### YAML syntax #####

| Key | Type  | Description | Allowed values | Default value |
| --- | ----- | ----------- | -------------- | ------------- |
| `command` | string | The command for running the profiling job. | `python -m online_endpoints_model_profiler ${{inputs.payload}}` | - |
| `experiment_name` | string | The experiment name of the profiling job. An experiment is a group of jobs. | - | - |
| `display_name` | string | The profiling job name. | - | A random string guid, such as `willing_needle_wrzk3lt7j5` |
| `environment.image` | string | An Azure Machine Learning curated image containing benchmarking tools and profiling scripts. | mcr.microsoft.com/azureml/online-endpoints-model-profiler:latest | - |
| `environment_variables` | string | Environment vairables for the profiling job. | [Profiling related environment variables](#YAML-profiling-related-environment_variables)<br><br>[Benchmarking tool related environment variables](#YAML-benchmarking-tool-related-environment_variables) | - |
| `compute` | string | The aml compute for running the profiling job. | - | - |
| `inputs.payload` | string | Payload file that is stored in an AML registered datastore. | [Example payload file content](https://github.com/Azure/azureml-examples/blob/xiyon/mir-profiling/cli/endpoints/online/profiling/payload.txt) | - |

##### YAML profiling related environment_variables #####    

<table>
<tr>
<td> Key </td> <td> Description </td> <td> Default Value </td>
</tr>
<tr>
<td> <code>SUBSCRIPTION</code> </td> <td> Used together with <code>RESOURCE_GROUP</code>, <code>WORKSPACE</code>, <code>ONLINE_ENDPOINT</code>, <code>DEPLOYMENT</code> to form the profiling target. </td> <td> Subscription of the profiling job </td>
</tr>
<tr>
<td> <code>RESOURCE_GROUP</code> </td> <td> Used together with <code>SUBSCRIPTION</code>, <code>WORKSPACE</code>, <code>ONLINE_ENDPOINT</code>, <code>DEPLOYMENT</code> to form the profiling target. </td> <td> Resource group of the profiling job </td>
</tr>
<tr>
<td> <code>WORKSPACE</code> </td> <td> Used together with <code>SUBSCRIPTION</code>, <code>RESOURCE_GROUP</code>, <code>ONLINE_ENDPOINT</code>, <code>DEPLOYMENT</code> to form the profiling target. </td> <td> AML workspace of the profiling job </td>
</tr>
<tr>
<td> <code>ONLINE_ENDPOINT</code> </td> 
<td> 
Used together with <code>SUBSCRIPTION</code>, <code>RESOURCE_GROUP</code>,  <code>WORKSPACE</code>, <code>DEPLOYMENT</code> to form the profiling target.<br>
<br>
If not provided, <code>SCORING_URI</code> will be used as the profiling target.<br>
<br>
If neither <code>OLINE_ENDPOINT</code>/<code>DEPLOYMENT</code> nor <code>SCORING_URI</code> is provided, an error will be thrown.
</td>
<td> - </td>
</tr>
<tr>
<td> <code>DEPLOYMENT</code> </td> 
<td> 
Used together with  <code>SUBSCRIPTION</code>, <code>RESOURCE_GROUP</code>,  <code>WORKSPACE</code>, <code>ONLINE_ENDPOINT</code> to form the profiling target.<br>
<br>
If not provided, <code>SCORING_URI</code> will be used as the profiling target.<br>
<br>
If neither <code>OLINE_ENDPOINT</code>/<code>DEPLOYMENT</code> nor <code>SCORING_URI</code> is provided, an error will be thrown. </td>
<td> - </td>
</tr>
<tr>
<td> <code>IDENTITY_ACCESS_TOKEN</code> </td>
<td> 
An optional aad token for retrieving online endpoint scoring_uri, access_key, and resource usage metrics. This will not be necessary for the following scenario:<br>
- The aml compute that is used to run the profiling job has contributor access to the workspace of the online endpoint.<br>
<br>
Users should keep in mind that it's recommended to assign appropriate permissions to the aml compute rather than providing this aad token, since the aad token might be expired during the process of the profiling job. 
</td>
<td> - </td>
</tr>
<tr>
<td> <code>SCORING_URI</code> </td> <td> Users are optional to provide this env var as instead of the <code>SUBSCRIPTION</code>/<code>RESOURCE_GROUP</code>/<code>WORKSPACE</code>/<code>ONLINE_ENDPOINT</code>/<code>DEPLOYMENT</code> combination to define the profiling target. Although, missing <code>ONLINE_ENDPOINT</code>/<code>DEPLOYMENT</code> info will lead to missing resource usage metrics in the final report. </td> <td> - </td>
</tr>
<tr>
<td> <code>SCORING_HEADERS</code> </td> <td> Users may use this env var to provide any special headers necessary when invoking the profiling target. </td>
<td> 

```json
{
    "Content-Type": "application/json",
    "Authorization": "Bearer ${ONLINE_ENDPOINT_ACCESS_KEY}",
    "azureml-model-deployment": "${DEPLOYMENT}"
}
```

</td>
</tr>
<tr>
<td> <code>PROFILING_TOOL</code> </td> <td> The name of the benchmarking tool. Currently support: <code>wrk</code>, <code>wrk2</code>, <code>labench</code>, <code>mlperf</code> </td> <td> <code>wrk</code> </td>
</tr>
<tr>
<td> <code>PAYLOAD</code> </td> 
<td>
Users may use this param to provide a single string format payload data for invoking the profiling target. For example: <code>{"data": [[1,2,3,4,5,6,7,8,9,10], [10,9,8,7,6,5,4,3,2,1]]}</code>.<br>
<br>
If <code>inputs.payload</code> is provided in the profiling job yaml file, this env var will be ignored.
</td>
<td> - </td>
</tr>
</table>

##### YAML benchmarking tool related environment_variables #####

| Key | Description | Default Value | wrk | wrk2 | labench | mlperf |
| --- | ----------- | ------------- | --- | ---- | ------- | ------ |
| `DURATION` | Period of time for running the benchmarking tool. | `300s` | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: |
| `CONNECTIONS` | No. of connections for the benchmarking tool. The default value will be set to the value of `max_concurrent_requests_per_instance` | `1` | :heavy_check_mark: | :heavy_check_mark: | :x: | :x: |
| `THREAD` | No. of threads allocated for the benchmarking tool. | `1` | :heavy_check_mark: | :heavy_check_mark: | :x: | :x: |
| `TARGET_RPS` | Target requests per second for the benchmarking tool. | `50` | :x: | :heavy_check_mark: | :heavy_check_mark: | :x: |
| `CLIENTS` | No. of clients for the benchmarking tool. The default value will be set to the value of `max_concurrent_requests_per_instance` | `1` | :x: | :x: | :heavy_check_mark: | :x: |
| `TIMEOUT` | Timeout in seconds for each request. | `10s` | :x: | :x: | :heavy_check_mark: | :x: |
| `TEST_MODE` | The test mode for mlperf. Allowed values: `server`, `searchThroughput`, `singleStream` | `singleStream` | :x: | :x: | :x: | :heavy_check_mark: |
| `TARGET_LATENCY_IN_MS` | Used together with `TARGET_LATENCY_PERCENTILE` to form the customer designated latency limitation for mlperf. | `10000` | :x: | :x: | :x: | :heavy_check_mark: |
| `TARGET_LATENCY_PERCENTILE` | Used together with `TARGET_LATENCY_IN_MS` to form the customer designated latency limitation for mlperf. | `90` | :x: | :x: | :x: | :heavy_check_mark: |
| `TARGET_RPS_LIST` | The list of target rps values. | `[]` | :x: | :x: | :x: | :heavy_check_mark: |
| `TARGET_SUCCESS_RATE` | Used together with the latency limitation, will ultimately decide if a profiling job result is VALID or not. | `99.99` | :x: | :x: | :x: | :heavy_check_mark: |
| `MIN_DURATION_IN_MS` | The minimum duration that the profiling job has to run. | `60000` | :x: | :x: | :x: | :heavy_check_mark: |
| `MIN_QUERY_COUNT` | The minimum number of queries that the profiling job has to send. | `singleStream`: 1024<br><br>`server`, `searchThroughput`:<br>- TARGET_LATENCY_PERCENTILE == 90: 24576<br>- TARGET_LATENCY_PERCENTILE == 95: 57344<br>- TARGET_LATENCY_PERCENTILE == 99: 270336<br>- else: 24576 | :x: | :x: | :x: | :heavy_check_mark: |

#### Create a profiling job with azure cli and ml extension

Update the profiling job yaml template with your own values and create a profiling job.

```bash
az ml job create -f ${PROFILING_JOB_YAML_FILE_PATH}
```

#### Read the performance report

* Users may find profiling job info in the AML workspace studio, under "Experiments" tab.
  ![image](https://user-images.githubusercontent.com/14539980/163346104-034d225e-ab58-4018-b712-d247c32d8823.png)

* Users may also find job metrics within each individual job page, under "Metrics" tab.
  ![image](https://user-images.githubusercontent.com/14539980/163347463-d9508c45-d724-49fd-baae-97e099f0b4f6.png)

* Users may also find job report file within each individual job page, under "Outputs + logs" tab, file "outputs/report.json".
  ![image](https://user-images.githubusercontent.com/14539980/163347805-a0269135-f615-4a7b-a13c-35630f0cb77a.png)
  
* Users may also use the following cli to download all job output files.

  ```bash
  az ml job download --name $JOB_ID --download-path $JOB_LOCAL_PATH
  ```

### Cleanup

Please use `az ml online-endpoint delete` to delete the test online endpoints and online deployment after completing profiling.

## Contact us

For any questions, bugs and requests of new features, please contact us at [mprof@microsoft.com](mailto:miroptprof@microsoft.com)
