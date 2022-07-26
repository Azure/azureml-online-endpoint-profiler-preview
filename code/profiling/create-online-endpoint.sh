# <set_variables>
export SKU_CONNECTION_PAIR=${SKU_CONNECTION_PAIR}
export ENDPOINT_NAME=${ENDPOINT_NAME}
export DEPLOYMENT_NAME=${DEPLOYMENT_NAME}
export DEPLOYMENT_COMPUTER_SIZE=`echo $SKU_CONNECTION_PAIR | awk -F: '{print $1}'`
# the computer size for the online-deployment
# </set_variables>

# <create_endpoint>
echo "Creating Endpoint $ENDPOINT_NAME of size $DEPLOYMENT_COMPUTER_SIZE..."
sed -e "s/<% COMPUTER_SIZE %>/$DEPLOYMENT_COMPUTER_SIZE/g" online-endpoint/blue-deployment-tmpl.yml > online-endpoint/${DEPLOYMENT_NAME}.yml
az ml online-endpoint create --name $ENDPOINT_NAME -f online-endpoint/endpoint.yml
az ml online-deployment create --name $DEPLOYMENT_NAME --endpoint $ENDPOINT_NAME -f online-endpoint/${DEPLOYMENT_NAME}.yml --all-traffic
# </create_endpoint>

# <check_endpoint_Status>
endpoint_status=`az ml online-endpoint show -n $ENDPOINT_NAME --query "provisioning_state" -o tsv`
echo $endpoint_status
if [[ $endpoint_status == "Succeeded" ]]; then
  echo "Endpoint $ENDPOINT_NAME created successfully"
else 
  echo "Endpoint $ENDPOINT_NAME creation failed"
  exit 1
fi

deploy_status=`az ml online-deployment show --name $DEPLOYMENT_NAME --endpoint-name $ENDPOINT_NAME --query "provisioning_state" -o tsv`
echo $deploy_status
if [[ $deploy_status == "Succeeded" ]]; then
  echo "Deployment $DEPLOYMENT_NAME completed successfully"
else
  echo "Deployment $DEPLOYMENT_NAME failed"
  exit 1
fi
# </check_endpoint_Status>