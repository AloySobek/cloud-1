#!/bin/bash
# File              : terraform-backend-creation.sh
# Author            : Rustam Khafizov <super.rustamm@gmail.com>
# Date              : 18.04.2021 23:03
# Last Modified Date: 19.04.2021 00:21
# Last Modified By  : Rustam Khafizov <super.rustamm@gmail.com>

#/bin/bash

if [[ $# -ne 4 ]] ; then
    printf 'You must provide\n\t1)project_id\n\t2)bucket_location\n\t3)bucket_name\n'
    exit 0
fi

gsutil mb -b on -p $1 -l $2 gs://$3/;
gsutil versioning set on gs://$3;
