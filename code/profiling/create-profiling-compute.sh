# <set_variables>
export PROFILER_COMPUTE_NAME="${PROFILER_COMPUTE_NAME}" # the compute name for hosting the profiler
export PROFILER_COMPUTE_SIZE="${PROFILER_COMPUTE_SIZE}" # the compute size for hosting the profiler
# </set_variables>

# <create_compute_cluster_for_hosting_the_profiler>
# skip compute creation if compute exists already
az ml compute show --name $PROFILER_COMPUTE_NAME
if [[ $? -eq 0 ]]; then echo "compute $PROFILER_COMPUTE_NAME exists already, will skip creation and role assignment." && exit 0; fi

echo "Creating Compute $PROFILER_COMPUTE_NAME ..."
az ml compute create --name $PROFILER_COMPUTE_NAME --size $PROFILER_COMPUTE_SIZE --identity-type SystemAssigned --type amlcompute --max-instances 3

# check compute status
compute_status=`az ml compute show --name $PROFILER_COMPUTE_NAME --query "provisioning_state" -o tsv`
echo $compute_status
if [[ $compute_status == "Succeeded" ]]; then
  echo "Compute $PROFILER_COMPUTE_NAME created successfully"
else 
  echo "Compute $PROFILER_COMPUTE_NAME creation failed"
  exit 1
fi

# create role assignment for acessing workspace resources
compute_info=`az ml compute show --name $PROFILER_COMPUTE_NAME --query '{"id": id, "identity_object_id": identity.principal_id}' -o json`
workspace_resource_id=`echo $compute_info | jq -r '.id' | sed 's/\(.*\)\/computes\/.*/\1/'`
identity_object_id=`echo $compute_info | jq -r '.identity_object_id'`
az role assignment create --role Contributor --assignee-object-id $identity_object_id --scope $workspace_resource_id
if [[ $? -ne 0 ]]; then echo "Failed to create role assignment for compute $PROFILER_COMPUTE_NAME" && exit 1; fi
# </create_compute_cluster_for_hosting_the_profiler>