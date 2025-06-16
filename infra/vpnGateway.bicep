// infra/vpnGateway.bicep
targetScope = 'resourceGroup'

@description('Azure region for the VPN gateway')
param location      string

@description('Name of the existing hub VNet')
param vnetName      string

@description('Name for the Public IP to associate with the VPN gateway')
param gatewayPip    string = 'hub-vpn-pip'

@description('Name of the VPN gateway')
param vpnGatewayName string = 'hub-vpn-gateway'

// 1️⃣ Create a Public IP for the VPN Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: gatewayPip
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 2️⃣ Reference the existing VNet (must have a subnet called "GatewaySubnet")
resource hubVnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: vnetName
}

// 3️⃣ Deploy the VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = {
  name: vpnGatewayName
  location: location

  properties: {
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false

    ipConfigurations: [
      {
        name: 'vpngw-ipconfig'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    sku: {
      name: 'VpnGw1' // Example SKU, adjust based on your requirements
      tier: 'VpnGw1' // Tier should match the SKU name
    }
  }
}
