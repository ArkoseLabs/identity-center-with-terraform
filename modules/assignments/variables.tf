// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "permission_sets" {
  type = list(string)
}

variable "permission_set_arns" {
  description = "Map of permission-set name => ARN for module-managed sets. Names present here use the resource ARN directly; names absent fall back to a data-source lookup (for externally managed permission sets)."
  type        = map(string)
  default     = {}
}

variable "principal" {
  type = string
}

variable "principal_type" {
  type = string
}

variable "account_assignment" {
  type = list(string)
}

variable "instances_arns" {
  type = string
}

variable "identity_store_id" {
  type = string
}
