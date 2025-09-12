/**
 * Copyright 2018 Google LLC
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

locals {
  // The roles in metadata.yaml are generated from per_module_roles.
  per_module_roles = {
    simple_bucket = [
      "roles/storage.admin",
      "roles/iam.serviceAccountUser",
      "roles/cloudkms.admin",
      "roles/logging.logWriter",
    ]
    root = [
      "roles/resourcemanager.projectIamAdmin",
      "roles/serviceusage.serviceUsageAdmin",
      "roles/storage.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/iam.serviceAccountUser",
    ]
  }
  extra_roles_for_tests = {
    simple_bucket = []
    root = [
      "roles/cloudkms.cryptoKeyEncrypterDecrypter",
    ]
  }
  // The roles given to the service accounts used for running tests.
  // Made by combining per_module_roles and extra_roles_for_tests.
  per_module_test_roles = {
    for module, module_roles in local.per_module_roles:
    module => setunion(module_roles, lookup(local.extra_roles_for_tests, module, []))
  }
}

resource "google_service_account" "int_test" {
  for_each = module.project

  project      = each.value.project_id
  account_id   = "ci-cloud-storage"
  display_name = "ci-cloud-storage"
}

resource "google_project_iam_member" "int_test" {
  // For each pair (moduleName, role), make a map entry from
  //   "moduleName.role" => {key, serviceAccount, role}
  // to apply below. Structure from https://discuss.hashicorp.com/t/foreach-loop-with-nested-list/54610.
  for_each = {
    for combination in flatten([
      for moduleName, proj in module.project : [
        for role in local.per_module_test_roles[moduleName]: {
          key             = "${moduleName}.${role}"
          service_account = google_service_account.int_test[moduleName]
          role            = role
        }
      ]
    ]) :
    combination.key => combination
  }

  project = each.value.service_account.project
  role    = each.value.role
  member  = "serviceAccount:${each.value.service_account.email}"
}

resource "google_service_account_key" "int_test" {
  for_each = module.project

  service_account_id = google_service_account.int_test[each.key].id
}
