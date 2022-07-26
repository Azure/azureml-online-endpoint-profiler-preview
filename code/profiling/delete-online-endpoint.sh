# <set_variables>
export ENDPOINT_NAME=${ENDPOINT_NAME}
# </set_variables>

# <delete_endpoint>
az ml online-endpoint delete --name $ENDPOINT_NAME -y
# </delete_endpoint>