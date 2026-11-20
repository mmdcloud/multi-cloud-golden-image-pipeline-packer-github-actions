# ==============================================================================
# Build Block & Provisioners Chain
# ==============================================================================

build {
  sources = [
    "source.amazon-ebs.builder",
    "source.googlecompute.builder",
    "source.azure-arm.builder"
  ]

  # Stage 1: Environment Bootstrapping (Prerequisites & Python/Ansible/Goss install)
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "BUILDER_TYPE=${build.Type}"
    ]
    script = "${path.root}/../scripts/bootstrap.sh"
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  # Stage 2: Ansible Provisioner (Enterprise CIS Hardening & Baseline Configuration)
  provisioner "ansible-local" {
    playbook_file   = "${path.root}/../ansible/playbook.yml"
    role_paths      = [
      "${path.root}/../ansible/roles/base",
      "${path.root}/../ansible/roles/cis_hardening",
      "${path.root}/../ansible/roles/cloud_agents"
    ]
    group_vars      = "${path.root}/../ansible/group_vars"
    extra_arguments = [
      "--extra-vars",
      "cloud_provider=${build.Type} cis_hardening_enabled=${var.enable_cis_hardening} compliance_level=${var.security_compliance_level} image_version=${var.image_version}"
    ]
  }

  # Stage 3: Automated Testing & CIS Compliance Verification with Goss
  provisioner "file" {
    source      = "${path.root}/../tests/goss"
    destination = "/tmp/goss-tests"
  }

  provisioner "shell" {
    environment_vars = [
      "ENABLE_TESTING=${var.enable_automated_testing}",
      "TEST_DIR=/tmp/goss-tests"
    ]
    script = "${path.root}/../scripts/run-goss-tests.sh"
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  # Stage 4: Cloud Sanitization & De-provisioning (Wipe credentials, logs, machine-id)
  provisioner "shell" {
    environment_vars = [
      "BUILDER_TYPE=${build.Type}"
    ]
    script = "${path.root}/../scripts/cleanup.sh"
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  # Post-Processor: Build Artifact Manifest
  post-processor "manifest" {
    output     = "${path.root}/../manifest-${build.Type}.json"
    strip_path = true
    custom_data = {
      image_name   = local.image_name
      base_os      = var.base_os
      version      = var.image_version
      builder      = build.Type
      build_id     = var.build_id
      git_commit   = var.git_commit_sha
      compliance   = var.security_compliance_level
    }
  }
}
