targetScope = 'resourceGroup'

@description('Azure region for Bastion')
param location    string

@description('Name of the existing hub VNet')
param vnetName    string

@description('Name for the Bastion host')
param bastionName string = 'hub-bastion'

@description('Name for the Public IP to use')
param pipName     string = 'hub-bastion-pip'

// 1. Public IP for Bastion
resource bastionPIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: pipName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

// 2. Reference hub VNet (so we can point at its subnet)
resource hubVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// 3. Deploy the Bastion host into AzureBastionSubnet
resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionName
  location: location
  sku: { name: 'Standard' }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: { id: bastionPIP.id }
        }
      }
    ]
  }
  dependsOn: [
    bastionPIP
  ]
}
