targetScope = 'resourceGroup'

@description('Name of the hub VNet')
param hubVnetName     string

@description('Name of the first spoke VNet (Web tier)')
param spoke1VnetName  string

@description('Name of the second spoke VNet (App tier)')
param spoke2VnetName  string

var hubId    = resourceId('Microsoft.Network/virtualNetworks', hubVnetName)
var spoke1Id = resourceId('Microsoft.Network/virtualNetworks', spoke1VnetName)
var spoke2Id = resourceId('Microsoft.Network/virtualNetworks', spoke2VnetName)

// 1️⃣ Hub → Spoke1: allow gateway transit
resource hubToSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${hubVnetName}/hub-to-spoke1'
  properties: {
    remoteVirtualNetwork: { id: spoke1Id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

// 2️⃣ Hub → Spoke2: allow gateway transit
resource hubToSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${hubVnetName}/hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: { id: spoke2Id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

// 3️⃣ Spoke1 → Hub: use remote gateways (depends on hubToSpoke1)
resource spoke1ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${spoke1VnetName}/spoke1-to-hub'
  dependsOn: [
    hubToSpoke1
  ]
  properties: {
    remoteVirtualNetwork: { id: hubId }
    allowVirtualNetworkAccess: true
    useRemoteGateways: true
  }
}

// 4️⃣ Spoke2 → Hub: use remote gateways (depends on hubToSpoke2)
resource spoke2ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${spoke2VnetName}/spoke2-to-hub'
  dependsOn: [
    hubToSpoke2
  ]
  properties: {
    remoteVirtualNetwork: { id: hubId }
    allowVirtualNetworkAccess: true
    useRemoteGateways: true
  }
}
