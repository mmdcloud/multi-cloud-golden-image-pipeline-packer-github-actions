# ==============================================================================
# GCP Provider Variables
# ==============================================================================
gcp_project_id              = "my-gcp-golden-image-project"
gcp_zone                    = "us-central1-a"
gcp_machine_type            = "e2-medium"
gcp_network                 = "default"
gcp_subnetwork              = ""

# Customer-Managed Encryption Key (CMEK) full resource ID (Optional)
# Format: projects/<project>/locations/<location>/keyRings/<keyRing>/cryptoKeys/<key>
gcp_cmek_key                = ""

# Storage regions for the resulting Compute Engine image
gcp_image_storage_locations = ["us"]
