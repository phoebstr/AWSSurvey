#!/usr/bin/env bash
# Compute inventory: EC2 instances, EBS volumes, AMIs, key pairs.
# Every section builds a JSON array and pipes through render(), so OUTPUT=json
# and OUTPUT=table are produced from the same source of truth.
source "$(dirname "$0")/lib.sh"
require_jq
preflight

hr "EC2 instances"
aws_q ec2 describe-instances \
| jq '[.Reservations[].Instances[] | {
      INSTANCE_ID:.InstanceId, TYPE:.InstanceType, STATE:.State.Name,
      AZ:.Placement.AvailabilityZone, PRIVATE_IP:(.PrivateIpAddress//"-"),
      PUBLIC_IP:(.PublicIpAddress//"-"),
      NAME:((.Tags//[])|map(select(.Key=="Name"))|.[0].Value // "-")
    }] | sort_by(.STATE)' \
| render "EC2 instances"

hr "EC2 count by type"
aws_q ec2 describe-instances \
| jq '[.Reservations[].Instances[] | .InstanceType]
      | group_by(.) | [.[] | {TYPE:.[0], COUNT:length}] | sort_by(-.COUNT)' \
| render "EC2 count by type"

hr "EBS volumes"
aws_q ec2 describe-volumes \
| jq '[.Volumes[] | {
      VOLUME_ID:.VolumeId, TYPE:.VolumeType, SIZE_GB:.Size, STATE:.State,
      ATTACHED_TO:((.Attachments//[])|.[0].InstanceId // "UNATTACHED")
    }]' \
| render "EBS volumes"

hr "AMIs (owned by this account)"
aws_q ec2 describe-images --owners self \
| jq '[.Images[] | {
      IMAGE_ID:.ImageId, NAME:(.Name//"-"), STATE:.State, CREATED:(.CreationDate//"-")
    }]' \
| render "AMIs"

hr "Key pairs"
aws_q ec2 describe-key-pairs \
| jq '[.KeyPairs[] | {
      KEY_NAME:.KeyName, TYPE:(.KeyType//"-"), FINGERPRINT:(.KeyFingerprint//"-")
    }]' \
| render "Key pairs"
