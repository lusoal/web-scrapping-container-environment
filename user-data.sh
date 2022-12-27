#!/bin/bash

ELASTIC_IPS=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]' | grep '"AllocationId":' | awk '{print $2}' | sed 's/\(.*\),/\1 /')
myArray=(${ELASTIC_IPS})

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)


echo "Allocating IP Alloc: ${myArray[0]} to instance ${INSTANCE_ID}"
ALLOCATION_ID=$(echo ${myArray[0]} | tr -d '"')

INTERFACE_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | jq '.Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId' | tr -d '"')

aws ec2 associate-address --network-interface-id ${INTERFACE_ID} --allocation-id ${ALLOCATION_ID}
