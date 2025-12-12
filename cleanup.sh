#!/bin/bash
RESOURCE_GROUP_NAME="rg-devops-multiip-test"

echo "Starting resource group deletion: $RESOURCE_GROUP_NAME"
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait

echo "Deletion request submitted. Check Azure Portal for status."