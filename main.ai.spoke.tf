locals {
  ai_spoke = {
    location            = "eastus2"
    resource_group_name = "rg-ai-foundry-spoke-eastus2"
    virtual_network = {
      name          = "vnet-ai-foundry-spoke-eastus2"
      address_space = ["10.10.0.0/16"]
    }
    hub = {
      resource_group_name  = "rg-alz-hub-eastus2"
      virtual_network_name = "vnet-alz-hub-eastus2"
      virtual_network_id   = "/subscriptions/${var.subscription_ids["connectivity"]}/resourceGroups/rg-alz-hub-eastus2/providers/Microsoft.Network/virtualNetworks/vnet-alz-hub-eastus2"
    }
    private_dns = {
      resource_group_name       = "rg-hub-dns-eastus2"
      auto_registration_zone    = "eastus2.azure.local"
      virtual_network_link_name = "vnet-link-vnet-ai-foundry-spoke-eastus2"
      private_link_zone_names = toset([
        "eastus2.azure.local",
        "privatelink-global.wvd.microsoft.com",
        "privatelink.1.azurestaticapps.net",
        "privatelink.2.azurestaticapps.net",
        "privatelink.3.azurestaticapps.net",
        "privatelink.4.azurestaticapps.net",
        "privatelink.5.azurestaticapps.net",
        "privatelink.adf.azure.com",
        "privatelink.afs.azure.net",
        "privatelink.agentsvc.azure-automation.net",
        "privatelink.analysis.windows.net",
        "privatelink.analytics.cosmos.azure.com",
        "privatelink.api.adu.microsoft.com",
        "privatelink.api.azureml.ms",
        "privatelink.attest.azure.net",
        "privatelink.azconfig.io",
        "privatelink.azure-api.net",
        "privatelink.azure-automation.net",
        "privatelink.azure-devices-provisioning.net",
        "privatelink.azure-devices.net",
        "privatelink.azurecr.io",
        "privatelink.azuredatabricks.net",
        "privatelink.azurehdinsight.net",
        "privatelink.azurehealthcareapis.com",
        "privatelink.azureiotcentral.com",
        "privatelink.azurestaticapps.net",
        "privatelink.azuresynapse.net",
        "privatelink.azurewebsites.net",
        "privatelink.batch.azure.com",
        "privatelink.blob.core.windows.net",
        "privatelink.cassandra.cosmos.azure.com",
        "privatelink.cognitiveservices.azure.com",
        "privatelink.database.windows.net",
        "privatelink.datafactory.azure.net",
        "privatelink.dev.azuresynapse.net",
        "privatelink.dfs.core.windows.net",
        "privatelink.dicom.azurehealthcareapis.com",
        "privatelink.digitaltwins.azure.net",
        "privatelink.directline.botframework.com",
        "privatelink.documents.azure.com",
        "privatelink.dp.kubernetesconfiguration.azure.com",
        "privatelink.eastus2.azmk8s.io",
        "privatelink.eastus2.azurecontainerapps.io",
        "privatelink.eastus2.kusto.windows.net",
        "privatelink.eastus2.prometheus.monitor.azure.com",
        "privatelink.eus2.backup.windowsazure.com",
        "privatelink.eventgrid.azure.net",
        "privatelink.fabric.microsoft.com",
        "privatelink.file.core.windows.net",
        "privatelink.grafana.azure.com",
        "privatelink.gremlin.cosmos.azure.com",
        "privatelink.guestconfiguration.azure.com",
        "privatelink.his.arc.azure.com",
        "privatelink.managedhsm.azure.net",
        "privatelink.mariadb.database.azure.com",
        "privatelink.media.azure.net",
        "privatelink.mongo.cosmos.azure.com",
        "privatelink.mongocluster.cosmos.azure.com",
        "privatelink.monitor.azure.com",
        "privatelink.mysql.database.azure.com",
        "privatelink.notebooks.azure.net",
        "privatelink.ods.opinsights.azure.com",
        "privatelink.oms.opinsights.azure.com",
        "privatelink.openai.azure.com",
        "privatelink.pbidedicated.windows.net",
        "privatelink.postgres.cosmos.azure.com",
        "privatelink.postgres.database.azure.com",
        "privatelink.prod.migration.windowsazure.com",
        "privatelink.purview-service.microsoft.com",
        "privatelink.purview.azure.com",
        "privatelink.purviewstudio.azure.com",
        "privatelink.queue.core.windows.net",
        "privatelink.redis.azure.net",
        "privatelink.redis.cache.windows.net",
        "privatelink.redisenterprise.cache.azure.net",
        "privatelink.search.windows.net",
        "privatelink.service.signalr.net",
        "privatelink.servicebus.windows.net",
        "privatelink.services.ai.azure.com",
        "privatelink.siterecovery.windowsazure.com",
        "privatelink.sql.azuresynapse.net",
        "privatelink.table.core.windows.net",
        "privatelink.table.cosmos.azure.com",
        "privatelink.tip1.powerquery.microsoft.com",
        "privatelink.token.botframework.com",
        "privatelink.ts.eventgrid.azure.net",
        "privatelink.vaultcore.azure.net",
        "privatelink.web.core.windows.net",
        "privatelink.webpubsub.azure.com",
        "privatelink.wvd.microsoft.com"
      ])
    }
  }
}

resource "azurerm_resource_group" "ai_spoke" {
  provider = azurerm.ai

  name     = local.ai_spoke.resource_group_name
  location = local.ai_spoke.location
  tags = merge(module.config.outputs.tags, {
    workload = "ai-foundry"
  })
}

resource "azurerm_virtual_network" "ai_spoke" {
  provider = azurerm.ai

  name                = local.ai_spoke.virtual_network.name
  location            = azurerm_resource_group.ai_spoke.location
  resource_group_name = azurerm_resource_group.ai_spoke.name
  address_space       = local.ai_spoke.virtual_network.address_space
  tags = merge(module.config.outputs.tags, {
    workload = "ai-foundry"
  })
}

resource "azurerm_virtual_network_peering" "hub_to_ai_spoke" {
  provider = azurerm.connectivity

  name                         = "peer-vnet-alz-hub-eastus2-to-vnet-ai-foundry-spoke-eastus2"
  resource_group_name          = local.ai_spoke.hub.resource_group_name
  virtual_network_name         = local.ai_spoke.hub.virtual_network_name
  remote_virtual_network_id    = azurerm_virtual_network.ai_spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = [module.hub_and_spoke_vnet]
}

resource "azurerm_virtual_network_peering" "ai_spoke_to_hub" {
  provider = azurerm.ai

  name                         = "peer-vnet-ai-foundry-spoke-eastus2-to-vnet-alz-hub-eastus2"
  resource_group_name          = azurerm_resource_group.ai_spoke.name
  virtual_network_name         = azurerm_virtual_network.ai_spoke.name
  remote_virtual_network_id    = local.ai_spoke.hub.virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true

  depends_on = [module.hub_and_spoke_vnet]
}

resource "azurerm_private_dns_zone_virtual_network_link" "ai_spoke" {
  provider = azurerm.connectivity

  for_each = local.ai_spoke.private_dns.private_link_zone_names

  name                  = local.ai_spoke.private_dns.virtual_network_link_name
  resource_group_name   = local.ai_spoke.private_dns.resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.ai_spoke.id
  registration_enabled  = each.value == local.ai_spoke.private_dns.auto_registration_zone
  tags = merge(module.config.outputs.tags, {
    workload = "ai-foundry"
  })

  depends_on = [
    azurerm_virtual_network_peering.hub_to_ai_spoke,
    azurerm_virtual_network_peering.ai_spoke_to_hub
  ]
}
