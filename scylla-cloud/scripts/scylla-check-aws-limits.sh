#!/usr/bin/env bash

set -e
quota=""

if [[ $1 = "--help" || $1 = "-h" ]]; then
    echo "Lists AWS quotas that are relevant for Scylla Cloud."
    echo "Assumes that AWS CLI is installed locally and uses it to perform AWS API requests."
    echo "Examples:"
    echo "  ./scylla-check-aws-limits.sh"
    echo "  AWS_PROFILE=lab ./scylla-check-aws-limits.sh"
    exit 0
fi

get_quota() {
  local out
  ret=0
  out=$(aws service-quotas get-service-quota --service-code "$1" --quota-code "$2" --query Quota.Value 2>&1) || ret=$?
  if [[ "$ret" = "0" ]]; then
    quota="$out"
  elif [[ "$out" =~ .*"NoSuchResourceException".*  ]]; then
    quota=$(aws service-quotas get-aws-default-service-quota --service-code "$1" --quota-code "$2" --query Quota.Value)
  else
    echo "$out"
    exit 1
  fi
}

get_quota vpc L-F678F1CE
echo "Amazon Virtual Private Cloud (Amazon VPC) - VPCs per region: $quota"
get_quota ec2 L-0263D0A3
echo "Amazon Elastic Compute Cloud (Amazon EC2) - EC2-VPC Elastic IPs: $quota"
get_quota ec2 L-1216C47A
echo "Amazon Elastic Compute Cloud (Amazon EC2) - Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances: $quota"
get_quota s3 L-DC2B2D3D
echo "Amazon Simple Storage Service (Amazon S3) - Buckets: $quota"
get_quota cloudformation L-0485CB21
echo "AWS CloudFormation - Stack count: $quota"
