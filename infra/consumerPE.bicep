// at the bottom of infra/appTier.bicep

@description('Name of the Private Endpoint to create in spoke2')
param peName string = 'workload-pe'

@description('Name of the Private Link Service (in workload VNet)')
param plsName string

@description('Consumer subnet name in spoke2-vnet')
param consumerSubnetName string = 'default'

@description('Location of the private endpoint resource')
param location string = resourceGroup().location

@description('Location of the private endpoint resource')
param vnetName string = 'spoke2-vnet'


// 1️⃣ Reference the consumer VNet & subnet
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}
var consumerSubnetId = '${spoke2Vnet.id}/subnets/${consumerSubnetName}'

// 2️⃣ Create the Private Endpoint in spoke2
resource pe 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: { id: consumerSubnetId }
    privateLinkServiceConnections: [
      {
        name: '${peName}-conn'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Network/privateLinkServices', plsName)
        }
      }
    ]
  }
}
