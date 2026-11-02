// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_ssoadmin_instances" "this" {}

locals {
  permission_sets = yamldecode(file(var.permission_sets))
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each         = local.permission_sets
  name             = each.key
  description      = each.value.description
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  tags             = each.value.tags
  session_duration = each.value.session_duration
  relay_state      = lookup(each.value, "relay_state", null)
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each           = { for ps, values in local.permission_sets : ps => values if values.inline_policy != null }
  inline_policy      = file("${var.policies}${each.value.inline_policy}.json")
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
}

module "aws_managed_policies" {
  source             = "./modules/aws_managed_policies"
  for_each           = { for ps, values in local.permission_sets : ps => values if values.aws_managed_policies != null }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  name               = each.value.aws_managed_policies
}

module "customer-managed_policies" {
  source             = "./modules/customer_managed_policies"
  for_each           = ({ for ps, values in local.permission_sets : ps => values if values.customer_managed_policies != null })
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  name               = each.value.customer_managed_policies
}

module "aws_permissions_boundary" {
  for_each             = { for ps, values in local.permission_sets : ps => values if values.permissions_boundary != null }
  source               = "./modules/permissions_boundary"
  instance_arn         = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn   = aws_ssoadmin_permission_set.this[each.key].arn
  permissions_boundary = each.value.permissions_boundary
}

module "account_assignment" {
  # NOTE: intentionally NO module-level depends_on here. A blanket
  # depends_on = [aws_ssoadmin_permission_set.this] forces every data source
  # in this module to re-read during apply whenever ANY permission set
  # changes, which turns permission_set_arn/principal_id into
  # (known after apply) and force-replaces every account assignment. Instead
  # we pass the created permission-set ARNs directly (see permission_set_arns)
  # so ordering is captured by a real reference edge, per-assignment.
  source             = "./modules/assignments"
  for_each           = yamldecode(file(var.account_assignments))
  principal          = each.value.principal
  principal_type     = each.value.principal_type
  permission_sets    = each.value.permission_sets
  account_assignment = each.value.account_list
  instances_arns     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id  = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # Module-managed permission-set ARNs. Assignments referencing a name in this
  # map use the resource ARN (known at plan for existing sets → no spurious
  # replacement); names absent here (externally managed) fall back to a
  # data-source lookup inside the submodule.
  permission_set_arns = { for name, ps in aws_ssoadmin_permission_set.this : name => ps.arn }
}