// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

# Only look up permission sets the caller did NOT supply an ARN for (e.g.
# externally/manually managed sets). Module-managed sets come in via
# var.permission_set_arns as resource references, so their ARN is known at
# plan time for existing sets — avoiding the force-replacement that a
# deferred data source would cause on every account assignment.
data "aws_ssoadmin_permission_set" "this" {
  for_each     = toset(local.fallback_permission_sets)
  instance_arn = var.instances_arns
  name         = each.value
}

data "aws_identitystore_group" "this" {
  count             = var.principal_type == "Group" ? 1 : 0
  identity_store_id = var.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = var.principal
    }
  }
}

data "aws_identitystore_user" "this" {
  count             = var.principal_type == "User" ? 1 : 0
  identity_store_id = var.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.principal
    }
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = { for account_set in local.account_permission_set : "${account_set.account}-${account_set.permission_set}" => account_set }

  instance_arn       = var.instances_arns
  permission_set_arn = local.resolved_permission_set_arns[each.value.permission_set]
  principal_id       = local.data_source
  principal_type     = local.principal_type_upper
  target_id          = each.value.account
  target_type        = "AWS_ACCOUNT"
}
