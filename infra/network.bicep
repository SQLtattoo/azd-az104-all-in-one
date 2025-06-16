targetScope = 'resourceGroup'

// Import common parameters - UPDATED PATH
module common 'common.bicep' = {
  name: 'common-params'
}

@description('Location for hub vnet resources')
param hublocation string

@description('Location for spoke1 vnet resources')
param spoke1location string

@description('Location for spoke2 vnet resources')
param spoke2location string

@description('Location for workload vnet resources')
param workloadlocation string

@description('Name of the hub virtual network')
param hubVnetName string
@description('Name of spoke #1 virtual network (web-tier)')
param spoke1VnetName string
@description('Name of spoke #2 virtual network (app-tier)')
param spoke2VnetName string
@description('Name of workload virtual network (private-link)')
param workloadVnetName string

// Use the common network address prefixes
var hubAddressPrefix      = common.outputs.networkAddressSpace.hub
var spoke1AddressPrefix   = common.outputs.networkAddressSpace.spoke1  
var spoke2AddressPrefix   = common.outputs.networkAddressSpace.spoke2
var workloadAddressPrefix = common.outputs.networkAddressSpace.workload

// Use the common subnet configurations
var bastionSubnetName = common.outputs.subnets.bastion.name
var bastionSubnetPrefix = common.outputs.subnets.bastion.prefix  
var gatewaySubnetName = common.outputs.subnets.gateway.name
var gatewaySubnetPrefix = common.outputs.subnets.gateway.prefix
var hubMgmtSubnetName = common.outputs.subnets.management.name
var hubMgmtSubnetPrefix = common.outputs.subnets.management.prefix

// Apply common tags to all resources - fixed to use object literal directly
var tags = {
  environment: 'demo'
  projectName: 'az104'
  CostControl: 'ignore'
  SecurityControl: 'ignore'
}

// Create Hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: hubVnetName
  location: hublocation
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ hubAddressPrefix ]
    }
    subnets: [
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: gatewaySubnetName
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: hubMgmtSubnetName
        properties: {
          addressPrefix: hubMgmtSubnetPrefix
        }
      }
    ]
  }
}

// Create NSG for Spoke #1
resource spoke1Nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${spoke1VnetName}-nsg'
  location: spoke1location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create NSG for Spoke #2
resource spoke2Nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${spoke2VnetName}-nsg'
  location: spoke2location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-AppGw'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-AppGw-Health'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create NSG for Workload VNet
resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${workloadVnetName}-nsg'
  location: workloadlocation
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create dedicated NSG for Application Gateway
resource appGwNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${spoke2VnetName}-appgw-nsg'
  location: spoke2location
  properties: {
    securityRules: [
      {
        name: 'Allow-GatewayManager'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Internet-HTTP'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Internet-HTTPS'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Create Route Table with custom route to Virtual Appliance
resource customRouteTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'custom-route-table'
  location: spoke2location 
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to-virtual-appliance'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.1.0.192'
        }
      }
    ]
  }
}

// Create Spoke #1 VNet with NSG directly associated in subnet properties
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: spoke1VnetName
  location: spoke1location
  properties: {
    addressSpace: {
      addressPrefixes: [ spoke1AddressPrefix ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: spoke1Nsg.id
          }
        }
      }
    ]
  }
}

// Create Spoke #2 VNet with NSG directly associated in subnet properties
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: spoke2VnetName
  location: spoke2location
  properties: {
    addressSpace: {
      addressPrefixes: [ spoke2AddressPrefix ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.3.1.0/24'
          networkSecurityGroup: {
            id: spoke2Nsg.id
          }
        }
      }
      {
        name: 'AppGwSubnet'
        properties: {
          addressPrefix: '10.3.2.0/24'
          networkSecurityGroup: {
            id: appGwNsg.id
          }
        }
      }
    ]
  }
}

// Create Workload VNet with NSG directly associated in subnet properties
resource workloadVnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: workloadVnetName
  location: workloadlocation
  properties: {
    addressSpace: {
      addressPrefixes: [ workloadAddressPrefix ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.4.1.0/24'
          networkSecurityGroup: {
            id: workloadNsg.id
          }
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Hub <--> Spoke1 peering
resource peerHubToSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: hubVnet
  name: 'hub-to-spoke1'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false      // Hub will share its gateway
    useRemoteGateways: false       // Hub does not use peer gateway
  }
}
resource peerSpoke1ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: spoke1Vnet
  name: 'spoke1-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    allowForwardedTraffic: false
    allowGatewayTransit: false
  }
}

// Hub <--> Spoke2 peering
resource peerHubToSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: hubVnet
  name: 'hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: {
      id: spoke2Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
resource peerSpoke2ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: spoke2Vnet
  name: 'spoke2-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    allowForwardedTraffic: false
    allowGatewayTransit: false
  }
}


