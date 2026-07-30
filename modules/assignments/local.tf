// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  principal_type_upper = upper(var.principal_type)
  principal_type_lower = lower(var.principal_type)

  data_source = var.principal_type == "User" ? data.aws_identitystore_user.this[0].user_id : data.aws_identitystore_group.this[0].group_id

  # Permission-set names not supplied by the caller need a data-source lookup.
  fallback_permission_sets = [
    for ps in var.permission_sets : ps if !contains(keys(var.permission_set_arns), ps)
  ]

  # Effective name => ARN: caller-supplied resource ARNs, plus data-source
  # ARNs for any externally managed sets.
  resolved_permission_set_arns = merge(
    var.permission_set_arns,
    { for name, ps in data.aws_ssoadmin_permission_set.this : name => ps.arn },
  )

  account_permission_set = flatten([
    for account in var.account_assignment : [
      for permission_set in var.permission_sets : {
        account        = account
        permission_set = permission_set
      }
    ]
  ])
}

