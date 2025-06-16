targetScope = 'resourceGroup'

@description('Name of the private DNS zone')
param privateDnsZoneName string

@description('Name of the hub VNet')
param hubVnetName        string

@description('Name of the web‐tier VNet (spoke1)')
param spoke1VnetName     string

@description('Name of the app‐tier VNet (spoke2)')
param spoke2VnetName     string

// Build the zone resource
resource privateZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}

// Hub VNet link - using parent property
resource hubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateZone
  name: 'link-to-hub'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', hubVnetName)
    }
    registrationEnabled: true
  }
}

// Spoke1 VNet link - using parent property
resource spoke1Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateZone
  name: 'link-to-spoke1'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', spoke1VnetName)
    }
    registrationEnabled: true
  }
}

// Spoke2 VNet link - using parent property
resource spoke2Link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateZone
  name: 'link-to-spoke2'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', spoke2VnetName)
    }
    registrationEnabled: true
  }
}
