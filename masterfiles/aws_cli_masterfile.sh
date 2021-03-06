#!/bin/bash
#this commands are used to create or delete AWS resources
#for .json files look in . folder or use  parameter  '--generate-cli-skeleton' for info

#set global DryRun flag for all commands: can be '--dry-run' or '--no-dry-run'
aws_dryrun='--no-dry-run'



#CREATE VPC
aws ec2 create-vpc $aws_dryrun --cli-input-json file://create-vpc_vpc01.json 1>create-vpc_vpc01.out;
#write VPC ID to file
aws_vpcid=$(cat create-vpc_vpc01.out | grep VpcId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g') &&  echo "aws_vpcid=$aws_vpcid" >> awsparams;

#CREATE internet gateway and attach it to vpc
aws ec2 create-internet-gateway $aws_dryrun 1>create-internet-gateway-igw01.out;
aws_igwid=$(cat create-internet-gateway-igw01.out | grep InternetGatewayId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g') &&  echo "aws_igwid=$aws_igwid" >> awsparams;
#attach Internet Gateway to VPC
aws ec2 attach-internet-gateway $aws_dryrun --internet-gateway-id $aws_igwid --vpc-id $aws_vpcid;

#CREATE 2 subnets
aws ec2  create-subnet $aws_dryrun --cidr-block 10.0.0.0/24 --availability-zone eu-central-1a --vpc-id $aws_vpcid 1>create-subnet-sub_s01.out;
aws_subnetid1=$(cat create-subnet-sub_s01.out | grep SubnetId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g') &&  echo "aws_subnetid1=$aws_subnetid1" >> awsparams;
aws ec2  create-subnet $aws_dryrun --cidr-block 10.0.1.0/24 --availability-zone eu-central-1b --vpc-id $aws_vpcid 1>create-subnet-sub_s02.out;
aws_subnetid2=$(cat create-subnet-sub_s02.out | grep SubnetId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g') &&  echo "aws_subnetid2=$aws_subnetid2" >> awsparams;
aws ec2 modify-subnet-attribute --map-public-ip-on-launch --subnet-id $aws_subnetid1;
aws ec2 modify-subnet-attribute --map-public-ip-on-launch --subnet-id $aws_subnetid2;

#CREATE route table  rules: add subnets and IGW
aws_rtbid=$(aws ec2 describe-route-tables | grep RouteTableId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g' | sed '1d') && echo "aws_rtbid=$aws_rtbid" >> awsparams;
aws ec2 create-route $aws_dryrun --route-table-id $aws_rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $aws_igwid 1>create-route_route01.out;
aws ec2 associate-route-table $aws_dryrun --route-table-id $aws_rtbid --subnet-id $aws_subnetid1 1>associate-rt-rule01.out;
aws ec2 associate-route-table $aws_dryrun --route-table-id $aws_rtbid --subnet-id $aws_subnetid2 1>associate-rt-rule02.out;

#CREATE security group and  add inbound 22,80,443 rules
aws ec2 create-security-group --vpc-id $aws_vpcid --group-name security_group01 --description "security group 01" --output text 1>create-security-group.out;
aws_securitygroup=$(cat create-security-group.out) && echo "aws_securitygroup=$aws_securitygroup" >> awsparams;
aws ec2 authorize-security-group-ingress --group-id $aws_securitygroup --protocol tcp --port 22  --cidr 0.0.0.0/0;
aws ec2 authorize-security-group-ingress --group-id $aws_securitygroup --protocol tcp --port 80  --cidr 0.0.0.0/0;
aws ec2 authorize-security-group-ingress --group-id $aws_securitygroup --protocol tcp --port 443 --cidr 0.0.0.0/0;

#CREATE 1 Amazon Linux t2.micro with new specified key-pair in subnet1
aws ec2 create-key-pair $aws_dryrun --key-name amazonlinux_t2micro_01 --query 'KeyMaterial' --output text > amazonlinux_t2micro_01.pem;
chmod 400 amazonlinux_t2micro_01.pem;
aws ec2 run-instances $aws_dryrun --image-id ami-5652ce39 --count 1 --instance-type t2.micro --key-name amazonlinux_t2micro_01 --security-group-ids $aws_securitygroup --subnet-id $aws_subnetid1 1>run-instances-ec2-01.out;
aws_instanceid01=$(cat run-instances-ec2-01.out | grep InstanceId | awk {'print $2'} | sed 's/"//g' | sed 's/,//g') &&  echo "aws_instanceid01=$aws_instanceid01" >> awsparams;
aws_instanceid01_private_ip=$(aws ec2 describe-instances --instance-ids $aws_instanceid01 | grep PrivateIpAddress | awk {'print $2'} | sed 's/"//g' | sed 's/,//g' | sed '1d' | sed '2,4d') &&  echo "aws_instanceid01_private_ip=$aws_instanceid01_private_ip" >> awsparams;
aws_instanceid01_public_ip=$(aws ec2 describe-instances --instance-ids $aws_instanceid01 | grep PublicIp | awk {'print $2'} | sed 's/"//g' | sed 's/,//g' | sed '1,2d') && echo "aws_instanceid01_public_ip=$aws_instanceid01_public_ip" >> awsparams;


#aws ec2 start-instances --instance-ids <value>
#aws ec2 stop-instances --instance-ids <value>
#default connect -> 'ssh -i "amazonlinux_t2micro_01.pem" ec2-user@<public_ip>'


#DELETE 1 Amazon Linux t2.micro with  specified key-pair in subnet1
aws ec2 delete-key-pair $aws_dryrun --key-name amazonlinux_t2micro_01;
chmod 600 key_amazonlinux_t2micro_01.pem && rm -f key_amazonlinux_t2micro_01.pem;
aws ec2 terminate-instances $aws_dryrun --instance-ids $aws_instanceid01 1>terminate-instances-ec2-01.out
sed -i '/aws_instanceid01/d' ./awsparams;

#DELETE security group
aws ec2 delete-security-group --group-id $aws_securitygroup;
sed -i '/aws_securitygroup/d' ./awsparams;

#DELETE route table  rules: remove subnets and IGW
aws ec2 delete-route $aws_dryrun --route-table-id $aws_rtbid --destination-cidr-block 0.0.0.0/0;

#DELETE 2 subnets
aws ec2  delete-subnet $aws_dryrun --subnet-id $aws_subnetid1;
aws ec2  delete-subnet $aws_dryrun --subnet-id $aws_subnetid2;
sed -i '/aws_subnetid/d' ./awsparams;

#DELETE internet gateway and deattach it from vpc
#deattach Internet Gateway from VPC
aws ec2 detach-internet-gateway $aws_dryrun --internet-gateway-id $aws_igwid --vpc-id $aws_vpcid;
#delete internet gateway
aws ec2 delete-internet-gateway $aws_dryrun --internet-gateway-id $aws_igwid;
sed -i '/aws_igwid/d' ./awsparams;

#DELETE VPC
aws ec2 delete-vpc --vpc-id $aws_vpcid $aws_dryrun;
sed -i '/aws_vpcid/d' ./awsparams;

