# Corresponds to secrets.TF_STATE_RG
resource_group_name  = "rg-tbc-app-services"

# Corresponds to secrets.TF_STATE_SA
storage_account_name = "tbcterraformstate"

# These are static in your workflow
container_name       = "tfstate"
key                  = "tbcdrupalmulti.tfstate"
