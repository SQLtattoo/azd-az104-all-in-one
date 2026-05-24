# AZ-104 Demo Environment Architecture

## Network Topology Diagram

```mermaid
flowchart TB
    subgraph Subscription["☁️ Azure Subscription"]

        subgraph Governance["📋 Governance (Subscription Scope)"]
            Policy["Azure Policy<br/>Allowed Locations<br/>Allowed VM Sizes"]
            RbacRole["Custom RBAC Role<br/>VM Support Engineer"]
        end

        subgraph HubRegion["📍 Hub Region"]
            subgraph HubVNet["hub-vnet 10.1.0.0/16"]
                BastionSubnet["AzureBastionSubnet<br/>10.1.1.0/26"]
                GatewaySubnet["GatewaySubnet<br/>10.1.2.0/27"]
                MgmtSubnet["hub-mgmt<br/>10.1.3.0/24"]

                Bastion["🔐 Azure Bastion<br/>Standard SKU<br/>⚡ Conditional"]
                VPNGw["🔗 VPN Gateway<br/>VpnGw1<br/>⚡ Conditional"]
            end
        end

        subgraph Spoke1Region["📍 Spoke 1 (Web Tier)"]
            subgraph Spoke1VNet["spoke1-vnet 10.2.0.0/16"]
                Spoke1NSG["NSG: Allow HTTP 80"]
                Spoke1Default["default 10.2.1.0/24"]

                subgraph WebTier["🌐 Web Tier"]
                    WebLB["⚖️ web-lb<br/>Public Standard LB"]
                    Web1VM["💻 web1-vm<br/>Windows Server 2019"]
                    Web2VM["💻 web2-vm<br/>Windows Server 2019"]
                end
            end
        end

        subgraph Spoke2Region["📍 Spoke 2 (App Tier)"]
            subgraph Spoke2VNet["spoke2-vnet 10.3.0.0/16"]
                Spoke2NSG["NSG: Allow HTTP 80"]
                Spoke2Default["default 10.3.1.0/24"]
                AppGwSubnet["AppGwSubnet 10.3.2.0/24"]

                subgraph AppTier["📱 App Tier"]
                    AppGw["🛡️ Application Gateway<br/>WAF_v2"]
                    AppVM["💻 vm1<br/>Windows Server 2019"]
                end

                subgraph ScaleTier["📐 Scale Set"]
                    VMSS["📐 vmssaz104<br/>VMSS Flexible<br/>2 instances<br/>Windows Server 2019"]
                end

                PE["🔒 Private Endpoint<br/>workload-pe"]
            end
        end

        subgraph WorkloadRegion["📍 Workload (Private Link)"]
            subgraph WorkloadVNet["workload-vnet 10.4.0.0/16"]
                WorkloadDefault["default 10.4.1.0/24"]

                subgraph WorkloadTier["⚙️ Workload Tier"]
                    WorkloadLB["⚖️ workload-lb<br/>Private Standard LB"]
                    WorkloadVM["💻 workload1-vm<br/>Windows Server 2019"]
                    PLS["🔗 Private Link Service<br/>workload-pls"]
                end
            end
        end

        subgraph SharedServices["🔧 Shared Services"]
            PublicDNS["🌍 Public DNS Zone<br/>contoso-xxxx.com"]
            PrivateDNS["🔒 Private DNS Zone<br/>contoso-xxxx.local"]
            RSV["💾 Recovery Services Vault<br/>contoso-rsv"]
            Storage["📦 Storage Account<br/>staz104xxxx — LRS"]
            KeyVault["🔑 Key Vault<br/>kv-az104-xxxx<br/>⚡ Conditional"]
        end

        subgraph Monitoring["📊 Monitoring (Conditional)"]
            LAW["Log Analytics Workspace<br/>az104-law-xxxx"]
            NetworkWatcher["Network Watcher"]
            DCR["Data Collection Rules<br/>AMA + Dependency Agent"]
            AlertGroup["Action Group<br/>Email Alerts"]
            ConnMonitor["Connection Monitor"]
        end

    end

    %% Bastion Access (conditional)
    Bastion -.->|"Secure RDP/SSH"| Web1VM
    Bastion -.->|"Secure RDP/SSH"| Web2VM
    Bastion -.->|"Secure RDP/SSH"| AppVM
    Bastion -.->|"Secure RDP/SSH"| WorkloadVM

    %% Subnet placements
    BastionSubnet --- Bastion
    GatewaySubnet --- VPNGw

    %% Web Tier flow
    WebLB --> Web1VM
    WebLB --> Web2VM
    Spoke1NSG --> Spoke1Default

    %% App Tier flow
    AppGw --> AppVM
    Spoke2NSG --> Spoke2Default

    %% VMSS in spoke2
    VMSS --- Spoke2Default

    %% Workload Tier flow
    WorkloadLB --> WorkloadVM
    PLS --- WorkloadLB

    %% Private Link flow
    PE -.->|"Private Link Connection"| PLS

    %% VNet Peering (Hub-Spoke)
    HubVNet <-->|"🔄 VNet Peering<br/>Gateway Transit"| Spoke1VNet
    HubVNet <-->|"🔄 VNet Peering<br/>Gateway Transit"| Spoke2VNet
    HubVNet <-->|"🔄 VNet Peering"| WorkloadVNet

    %% DNS Links
    PrivateDNS -.->|"VNet Link"| HubVNet
    PrivateDNS -.->|"VNet Link"| Spoke1VNet
    PrivateDNS -.->|"VNet Link"| Spoke2VNet

    %% Monitoring links
    LAW --- DCR
    DCR -.->|"AMA"| Web1VM
    DCR -.->|"AMA"| Web2VM
    DCR -.->|"AMA"| AppVM
    DCR -.->|"AMA"| WorkloadVM
    LAW --- AlertGroup
    NetworkWatcher --- ConnMonitor

    %% Styling
    classDef hub fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef spoke fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef workload fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef shared fill:#fafafa,stroke:#616161,stroke-width:2px
    classDef security fill:#ffebee,stroke:#b71c1c,stroke-width:2px
    classDef optional fill:#fff9c4,stroke:#f57f17,stroke-width:2px,stroke-dasharray: 5 5
    classDef governance fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef monitoring fill:#e3f2fd,stroke:#0d47a1,stroke-width:2px

    class HubVNet,BastionSubnet,GatewaySubnet,MgmtSubnet hub
    class Bastion,VPNGw optional
    class Spoke1VNet,WebTier spoke
    class Spoke2VNet,AppTier,ScaleTier spoke
    class WorkloadVNet,WorkloadTier workload
    class SharedServices shared
    class AppGw,PE security
    class KeyVault optional
    class Governance governance
    class Monitoring,LAW,DCR,AlertGroup,NetworkWatcher,ConnMonitor monitoring
```

## Resource Summary

| Category | Resource | SKU/Tier | Location | Conditional |
|----------|----------|----------|----------|-------------|
| **Networking** | hub-vnet | - | Hub | No |
| | spoke1-vnet | - | Spoke1 | No |
| | spoke2-vnet | - | Spoke2 | No |
| | workload-vnet | - | Workload | No |
| | NSG (spoke1) | Allow HTTP | Spoke1 | No |
| | NSG (spoke2) | Allow HTTP | Spoke2 | No |
| **Gateways** | VPN Gateway | VpnGw1 | Hub | Yes (`deployVpnGateway`) |
| | Azure Bastion | Standard | Hub | Yes (`deployBastion`) |
| **Load Balancing** | web-lb | Public Standard | Spoke1 | No |
| | workload-lb | Private Standard | Workload | No |
| | Application Gateway | WAF_v2 | Spoke2 | No |
| **Compute** | web1-vm, web2-vm | B2s_v2 (default) | Spoke1 | No |
| | vm1 | B2s_v2 (default) | Spoke2 | No |
| | workload1-vm | B2s_v2 (default) | Workload | No |
| | vmssaz104 | B2s_v2 / 2 instances | Spoke2 | No |
| **Private Link** | workload-pls | - | Workload | No |
| | workload-pe | - | Spoke2 | No |
| **Shared** | Public DNS Zone | contoso-xxxx.com | Global | No |
| | Private DNS Zone | contoso-xxxx.local | Global | No |
| | Recovery Services Vault | RS0 Standard | Hub | No |
| | Storage Account | Standard LRS | Hub | No |
| | Key Vault | Standard | Hub | Yes (`deployKeyVault`) |
| **Governance** | Azure Policy | Allowed Locations | Subscription | No |
| | Azure Policy | Allowed VM Sizes | Subscription | No |
| | Custom Role | VM Support Engineer | Subscription | No |
| **Monitoring** | Log Analytics Workspace | - | Hub | Yes (`deployMonitoring`) |
| | Network Watcher | - | All regions | Yes |
| | DCR + AMA | VM Insights | All tiers | Yes |
| | Connection Monitor | - | Hub | Yes |
| | Action Group / Alerts | Email | Hub | Yes |

## Deployment Toggles

| Parameter | Default | Description |
|-----------|---------|-------------|
| `deployBastion` | `true` | Deploy Azure Bastion in hub |
| `deployVpnGateway` | `true` | Deploy VPN Gateway + Gateway Transit |
| `deployKeyVault` | `true` | Deploy Key Vault for CMK demos |
| `enableCmkForStorage` | `false` | Enable Customer-Managed Keys on Storage |
| `deployMonitoring` | `true` | Deploy full monitoring stack |

## VM Size Overrides

| Parameter | Default | Applies To |
|-----------|---------|------------|
| `defaultVmSize` | `Standard_B2s_v2` | All tiers (fallback) |
| `webTierVmSize` | `''` (uses default) | web1-vm, web2-vm |
| `appTierVmSize` | `''` (uses default) | vm1 |
| `workloadTierVmSize` | `''` (uses default) | workload1-vm |
| `vmssVmSize` | `''` (uses default) | vmssaz104 |
