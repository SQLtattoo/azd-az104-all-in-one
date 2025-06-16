@description('Name of the NSG')
param nsgName string

@description('Location for the NSG')
param location string

@description('Array of security rules')
param securityRules array = []

@description('Tags to apply to the NSG')
param tags object = {}

// Create NSG with provided rules
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

output id string = nsg.id
output name string = nsg.name
