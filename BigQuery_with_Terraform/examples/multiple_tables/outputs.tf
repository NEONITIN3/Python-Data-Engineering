/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "bigquery_dataset" {
  value       = module.bigquery.bigquery_dataset
  description = "Bigquery dataset resource."
}

output "bigquery_tables" {
  value       = module.bigquery.bigquery_tables
  description = "Map of bigquery table resources being provisioned."
}

output "bigquery_external_tables" {
  value       = module.bigquery.bigquery_external_tables
  description = "Map of bigquery table resources being provisioned."
}

output "bigquery_auth_dataset" {
  value       = module.auth_dataset.bigquery_dataset
  description = "Authorized Bigquery dataset resource."
}

output "authorization" {
  value       = module.add_authorization.authorized_dataset["${module.auth_dataset.bigquery_dataset.project}_${module.auth_dataset.bigquery_dataset.dataset_id}"]
  description = "Authorization Bigquery dataset resource."
}
