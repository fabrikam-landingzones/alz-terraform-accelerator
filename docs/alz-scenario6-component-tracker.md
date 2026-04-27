# ALZ Scenario 6 Component Tracker

Date: 2026-04-26

Purpose: track the required Scenario 6 platform components, the client-specific exclusions, and the current implementation status before moving to the AI Landing Zone deployment.

## Status Legend

| Status | Meaning |
| --- | --- |
| Complete | Implemented and validated in Azure. |
| In progress | Implemented in Terraform and waiting for pipeline validation. |
| Excluded | Intentionally not deployed by client decision. |
| Pending | Required or recommended, but not yet implemented. |
| Deferred | Known item intentionally postponed. |

## Scenario 6 Platform Components

| Component | Target state | Status | Evidence / notes |
| --- | --- | --- | --- |
| ALZ management group hierarchy | New ALZ hierarchy under `Fabrikam` | Complete | Management groups deployed and visible in Azure. |
| Subscription placement | Workload subscriptions placed under intended ALZ management groups | Complete | Tag `alz-scenario6-subscriptions-placed`; AI subscription is under `ai`. |
| Management subscription resources | Log Analytics, management resource groups, monitoring foundation | Complete | `rg-management-eastus2`, `rg-fabalz-fabmgmt-state-eastus2-001`, `rg-fabalz-fabmgmt-identity-eastus2-001`. |
| Connectivity hub resource group | Terraform-managed hub resource group | Complete | `rg-alz-hub-eastus2` in Connectivity subscription. |
| Hub VNet | Terraform-managed hub virtual network | Complete | `vnet-alz-hub-eastus2` with address space `10.0.0.0/22`. |
| Azure Firewall | Not deployed | Excluded | Client requirement: do not deploy Azure Firewall. |
| DDoS Protection | Not deployed | Excluded | Client requirement: do not deploy DDoS Protection. |
| Azure Bastion | Not deployed | Excluded | Client requirement: do not deploy Azure Bastion. |
| Private DNS zones | Deployed and managed for Private Link foundation | Complete | `rg-hub-dns-eastus2` contains ALZ private DNS zones. |
| Deploy-Private-DNS-Zones policy | Restored | Complete | Policy was re-enabled after earlier temporary removal. |
| Azure DNS Private Resolver | Deployed in hub | Complete | `pdr-alz-hub-dns-eastus2` visible from hub VNet DNS blade. |
| S2S VPN gateway | Deployed in hub VNet | Complete | `vgw-alz-hub-vpn-eastus2`. |
| S2S VPN connection | Connected to home UDR7 | Complete | `conn-alz-home-udr7` status `Connected`; peer `lng-alz-home-udr7`. |
| AI spoke VNet | Dedicated BYO VNet for upcoming AI Landing Zone | Complete | `rg-ai-foundry-spoke-eastus2` and `vnet-ai-foundry-spoke-eastus2` validated in the AI subscription. Address space expanded to `10.10.0.0/16` on 2026-04-27. |
| AI spoke subnets | Created by the AI Landing Zone module, not by ALZ | Deferred to AI Landing Zone phase | The three provisional ALZ-managed subnets and NSGs were removed on 2026-04-27 so the official AI Landing Zone module can own its required subnets in its own Terraform state. |
| Hub-to-spoke peering | Bidirectional peering with gateway transit | Complete | Hub peering is `Connected` with `allowGatewayTransit=True`; spoke peering is `Connected` with `useRemoteGateways=True`. |
| Spoke Private DNS links | AI spoke linked to existing private DNS zones | Complete | Key zones including `privatelink.openai.azure.com`, `privatelink.services.ai.azure.com`, and `privatelink.blob.core.windows.net` are linked to the spoke. |
| Change tracking | Enabled | Complete | `change_tracking` was restored in the management configuration. |
| Defender for SQL | Not in current scope | Deferred | Client requirement: do not focus on Defender for SQL at this stage. |
| Terraform refresh workaround | Remove `-refresh=false` when provider/API issue is resolved | Deferred | Current workflow still uses `-refresh=false` due Azure API 500 on VPN shared key refresh. |
| Old manually created environment cleanup | Delete only the explicitly approved old resource groups | Complete | The 8 approved old resource groups were deleted and verified as no longer existing on 2026-04-26. Current ALZ resource groups were preserved. |

## AI Spoke VNet Design

| Setting | Value |
| --- | --- |
| Subscription | AI subscription `e4092919-7fd6-46bb-94fe-955fd8cc7ca1` |
| Resource group | `rg-ai-foundry-spoke-eastus2` |
| VNet | `vnet-ai-foundry-spoke-eastus2` |
| VNet address space | `10.0.4.0/22` |
| Private endpoint subnet | `snet-ai-foundry-private-endpoints` / `10.0.4.0/24` |
| Workload subnet | `snet-ai-foundry-workloads` / `10.0.5.0/24` |
| Agent subnet | `snet-ai-foundry-agents` / `10.0.6.0/24` |
| Private endpoint subnet NSG | `nsg-ai-foundry-private-endpoints` |
| Workload subnet NSG | `nsg-ai-foundry-workloads` |
| Agent subnet NSG | `nsg-ai-foundry-agents` |
| Hub VNet | `vnet-alz-hub-eastus2` / `10.0.0.0/22` |
| Home/on-premises ranges | `192.168.4.0/24`, `192.168.1.0/24` |

## Operational Prerequisites Added for Spoke Deployment

The GitHub Actions plan and apply service principals need access to the AI subscription because the spoke resource group and VNet are deployed there.

Run from any Azure CLI authenticated PowerShell session with permission to assign roles on the AI subscription:

```powershell
az role assignment create `
  --assignee-object-id a9d5049c-517b-407d-988d-3a46e314829c `
  --assignee-principal-type ServicePrincipal `
  --role Reader `
  --scope /subscriptions/e4092919-7fd6-46bb-94fe-955fd8cc7ca1
```

Expected result: a JSON role assignment showing `roleDefinitionId` for Reader and `principalId` `a9d5049c-517b-407d-988d-3a46e314829c`.

```powershell
az role assignment create `
  --assignee-object-id ccf2c5f7-2646-46be-897a-771dd053c82c `
  --assignee-principal-type ServicePrincipal `
  --role Contributor `
  --scope /subscriptions/e4092919-7fd6-46bb-94fe-955fd8cc7ca1
```

Expected result: a JSON role assignment showing `roleDefinitionId` for Contributor and `principalId` `ccf2c5f7-2646-46be-897a-771dd053c82c`.

Do not continue to the Terraform pipeline until these role assignments exist, otherwise the plan/apply identities cannot read or create resources in the AI subscription.

The Terraform backend storage account must also be reachable from GitHub-hosted runners. During this implementation the backend state storage account had RBAC configured correctly but `publicNetworkAccess` was disabled, which caused `terraform init` to fail with `403 listing blobs`.

Run from an Azure CLI authenticated PowerShell session with permission to update the backend storage account:

```powershell
az storage account update `
  --subscription 1e21d1d0-beb6-4e0e-bb8b-488fd7d39f76 `
  --resource-group rg-fabalz-fabmgmt-state-eastus2-001 `
  --name stofabfabeas001vjiu `
  --public-network-access Enabled `
  --default-action Allow
```

Expected result: `publicNetworkAccess` is `Enabled`. `allowSharedKeyAccess` should remain `false`; Terraform continues to authenticate to the backend with Azure AD/RBAC.

## Implementation Notes From AI Spoke Deployment

The first apply attempt failed because ALZ policy requires every subnet to have a Network Security Group at creation time.

Resolution:

```text
Create an NSG per subnet.
Create subnets with azapi_resource so networkSecurityGroup.id is included in the initial subnet PUT request.
```

The second apply attempt hit an Azure Network API concurrency conflict:

```text
AnotherOperationInProgress
```

Resolution:

```text
Add -parallelism=1 to terraform apply in .github/workflows/cd.yaml.
```

This serializes Azure network updates during apply and avoids parallel subnet operations against the same VNet.

## Validation Commands After Pipeline Success

Run these commands from:

```powershell
C:\Users\renatocamara\projects\landingzone\alz\alz-terraform-accelerator-deploy
```

Validate the AI spoke resource group:

```powershell
az group show `
  --subscription e4092919-7fd6-46bb-94fe-955fd8cc7ca1 `
  --name rg-ai-foundry-spoke-eastus2 `
  --query "{name:name, location:location, tags:tags}" `
  -o json
```

Expected result: JSON showing `name` as `rg-ai-foundry-spoke-eastus2` and `location` as `eastus2`.

Validate the AI spoke VNet and subnets:

```powershell
az network vnet show `
  --subscription e4092919-7fd6-46bb-94fe-955fd8cc7ca1 `
  --resource-group rg-ai-foundry-spoke-eastus2 `
  --name vnet-ai-foundry-spoke-eastus2 `
  --query "{name:name, addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name, prefixes:addressPrefixes}}" `
  -o json
```

Expected result: address space `10.0.4.0/22` and the three subnets `snet-ai-foundry-private-endpoints`, `snet-ai-foundry-workloads`, and `snet-ai-foundry-agents`.

Validate hub peering:

```powershell
az network vnet peering list `
  --subscription 2a43354d-ac7c-44a4-9a65-3cc7868cdbdb `
  --resource-group rg-alz-hub-eastus2 `
  --vnet-name vnet-alz-hub-eastus2 `
  --query "[].{name:name, state:peeringState, allowGatewayTransit:allowGatewayTransit, remote:remoteVirtualNetwork.id}" `
  -o table
```

Expected result: peering to `vnet-ai-foundry-spoke-eastus2` with `Connected` state and gateway transit enabled.

Validate spoke peering:

```powershell
az network vnet peering list `
  --subscription e4092919-7fd6-46bb-94fe-955fd8cc7ca1 `
  --resource-group rg-ai-foundry-spoke-eastus2 `
  --vnet-name vnet-ai-foundry-spoke-eastus2 `
  --query "[].{name:name, state:peeringState, useRemoteGateways:useRemoteGateways, remote:remoteVirtualNetwork.id}" `
  -o table
```

Expected result: peering to `vnet-alz-hub-eastus2` with `Connected` state and `useRemoteGateways` enabled.

Validate Private DNS links for key AI/Private Link zones:

```powershell
az network private-dns link vnet list `
  --subscription 2a43354d-ac7c-44a4-9a65-3cc7868cdbdb `
  --resource-group rg-hub-dns-eastus2 `
  --zone-name privatelink.openai.azure.com `
  --query "[?contains(virtualNetwork.id, 'vnet-ai-foundry-spoke-eastus2')].{name:name, registrationEnabled:registrationEnabled, state:virtualNetworkLinkState}" `
  -o table
```

Expected result: one link for `vnet-ai-foundry-spoke-eastus2`.

```powershell
az network private-dns link vnet list `
  --subscription 2a43354d-ac7c-44a4-9a65-3cc7868cdbdb `
  --resource-group rg-hub-dns-eastus2 `
  --zone-name privatelink.services.ai.azure.com `
  --query "[?contains(virtualNetwork.id, 'vnet-ai-foundry-spoke-eastus2')].{name:name, registrationEnabled:registrationEnabled, state:virtualNetworkLinkState}" `
  -o table
```

Expected result: one link for `vnet-ai-foundry-spoke-eastus2`.

After all validations pass, create a checkpoint tag:

```powershell
git tag alz-scenario6-ai-spoke-working
git push origin alz-scenario6-ai-spoke-working
```

Expected result: GitHub receives the new tag and the deployment has a rollback/reference point before starting the AI Landing Zone implementation.

## Final ALZ Sanity Check - 2026-04-26

This check confirms that the current ALZ Scenario 6 implementation, with the approved client exclusions, is ready for the next phase: AI Landing Zone deployment.

### Terraform Validation

Run from:

```text
C:\Users\renatocamara\projects\landingzone\alz\alz-terraform-accelerator-deploy
```

Commands:

```powershell
terraform fmt -check -recursive
terraform validate
$env:TF_VAR_vpn_shared_key = "ReplaceWithAStrongSharedKey123!"
terraform plan -input=false -refresh=false -detailed-exitcode
```

Validated result:

```text
terraform fmt -check -recursive completed successfully.
terraform validate returned: Success! The configuration is valid.
terraform plan returned: No changes. Your infrastructure matches the configuration.
```

Note: `-refresh=false` remains intentional because of the known Azure API/provider refresh issue on the VPN connection shared key.

### Azure Resource Validation

Validated resource groups that must remain:

| Subscription | Resource group | Result |
| --- | --- | --- |
| Connectivity | `rg-alz-hub-eastus2` | Exists |
| Connectivity | `rg-hub-dns-eastus2` | Exists |
| AI | `rg-ai-foundry-spoke-eastus2` | Exists |
| Management | `rg-management-eastus2` | Exists |
| Management | `rg-fabalz-fabmgmt-state-eastus2-001` | Exists |
| Management | `rg-fabalz-fabmgmt-identity-eastus2-001` | Exists |

Validated old resource groups deleted after explicit approval:

| Subscription | Resource group | Result |
| --- | --- | --- |
| AI | `rg-ai-foundry-dev-eastus2` | Does not exist |
| AI | `rg-ai-spoke-eastus2` | Does not exist |
| Connectivity | `rg-hub-eastus2` | Does not exist |
| Connectivity | `rg-platform-keyvault-eastus2` | Does not exist |
| CORP | `rg-corp-privatelink-dev-eastus2` | Does not exist |
| CORP | `rg-spoke-dev-eastus2` | Does not exist |
| Sandbox | `rg-alz01-lab-identity-eastus2-001` | Does not exist |
| Sandbox | `rg-alz01-lab-state-eastus2-001` | Does not exist |

### Final Component Results

| Component | Expected state | Result |
| --- | --- | --- |
| Management group hierarchy | ALZ hierarchy under `Fabrikam` | Complete |
| Subscription placement | Platform and workload subscriptions under the intended ALZ management groups | Complete |
| Hub VNet | `vnet-alz-hub-eastus2`, address space `10.0.0.0/22` | Complete |
| Hub subnets | `dns-resolver`, `GatewaySubnet` | Complete |
| Private DNS zones | 90 private DNS zones in `rg-hub-dns-eastus2` | Complete |
| DNS Private Resolver | `pdr-alz-hub-dns-eastus2` in `rg-alz-hub-eastus2` | Complete |
| S2S VPN | `conn-alz-home-udr7` connected by IPsec | Complete |
| AI spoke VNet | `vnet-ai-foundry-spoke-eastus2`, address space `10.10.0.0/16` | Complete |
| AI spoke subnets | No ALZ-managed subnets; subnets will be created by the AI Landing Zone deployment | Deferred to AI Landing Zone phase |
| Hub-to-spoke peering | Connected, with gateway transit enabled from the hub | Complete |
| Spoke-to-hub peering | Connected, with remote gateway usage enabled from the spoke | Complete |
| AI spoke Private DNS links | Key AI and Private Link zones linked to the AI spoke | Complete |
| Azure Firewall | Not deployed | Excluded by requirement |
| DDoS Protection | Not deployed | Excluded by requirement |
| Azure Bastion | Not deployed | Excluded by requirement |
| Defender for SQL | Not part of this phase | Deferred |

### Conclusion

There are no remaining required ALZ Scenario 6 platform tasks before starting the AI Landing Zone phase. The next implementation should treat the AI spoke VNet as an existing/BYO network and deploy Azure AI Foundry resources and its required subnets into that prepared spoke model.

### 2026-04-27 AI Landing Zone Network Preparation Update

The AI spoke was expanded from a small `/22` to a larger non-overlapping `/16`:

```text
Old: 10.0.4.0/22
New: 10.10.0.0/16
```

Rationale:

```text
10.0.0.0/16 could not be used because it would overlap the ALZ hub address space 10.0.0.0/22.
192.168.0.0/16 was rejected because it overlaps the home network ranges used across the S2S VPN.
10.10.0.0/16 gives enough room for the AI Landing Zone and future expansion without overlapping the hub or home network.
```

The provisional ALZ-created subnets were removed:

```text
snet-ai-foundry-private-endpoints
snet-ai-foundry-workloads
snet-ai-foundry-agents
```

Their NSGs were also removed:

```text
nsg-ai-foundry-private-endpoints
nsg-ai-foundry-workloads
nsg-ai-foundry-agents
```

Why:

```text
The official Azure AI Landing Zone Terraform module creates its own required subnets inside the BYO VNet. Pre-creating those subnets in the ALZ Terraform state would create ownership conflicts between the ALZ state and the AI Landing Zone state.
```

Final validation:

```powershell
$env:TF_VAR_vpn_shared_key = "ReplaceWithAStrongSharedKey123!"
terraform plan -input=false -refresh=false -detailed-exitcode
```

Validated result:

```text
No changes. Your infrastructure matches the configuration.
```

Planned AI Landing Zone subnet ownership:

| Subnet purpose | Created by | Initial status |
| --- | --- | --- |
| Private Endpoints subnet | AI Landing Zone module | Required |
| AI Foundry Agent subnet / capability host subnet | AI Landing Zone module | Required if AI Agent Service is enabled |
| Build agent subnet | AI Landing Zone module | Recommended / module default |
| Container App Environment subnet | AI Landing Zone module | Recommended / module default |
| API Management subnet | AI Landing Zone module | Optional unless APIM is deployed |
| Application Gateway subnet | AI Landing Zone module | Optional unless Application Gateway is deployed |
| Jump box subnet | AI Landing Zone module | Optional; not planned for initial private VPN access path |
