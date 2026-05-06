
terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
}
resource "scaleway_registry_namespace" "main" {
  name = "jenkins-registry"
  is_public = false
  project_id = var.project_id
}

resource "scaleway_container_namespace" "main" {
  name = "production-ns"
  description = "Namespace for serverless containers deployment"
  project_id = var.project_id
}

resource "scaleway_iam_application" "jenkins_push" {
  name = "jenkins-registry-push"
  organization_id = var.organization_id
}

resource "scaleway_iam_application" "jenkins_pull" {
  name = "jenkins-registry-pull"
  organization_id = var.organization_id
}

resource "time_rotating" "rotate_after_a_year" {
  rotation_years = 1
}

resource "scaleway_iam_api_key" "jenkins_push" {
  application_id = scaleway_iam_application.jenkins_push.id
  description    = "Jenkins push key"
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

resource "scaleway_iam_api_key" "jenkins_pull" {
  application_id = scaleway_iam_application.jenkins_pull.id
  description    = "Jenkins pull key"
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

# Policy push — accès write au registry
resource "scaleway_iam_policy" "registry_push" {
  name           = "registry-push-policy"
  application_id = scaleway_iam_application.jenkins_push.id
  organization_id = var.organization_id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

# Policy pull — accès read only au registry
resource "scaleway_iam_policy" "registry_pull" {
  name           = "registry-pull-policy"
  application_id = scaleway_iam_application.jenkins_pull.id
  organization_id = var.organization_id

  rule {
    project_ids          = [var.project_id]
    permission_set_names = ["ContainerRegistryReadOnly", "ContainersFullAccess"]
  }
}