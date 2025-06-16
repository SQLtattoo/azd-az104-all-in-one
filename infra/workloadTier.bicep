// infra/workloadTier.bicep
targetScope = 'resourceGroup'

@description('Location for workload tier resources')
param location string

@description('Name of the workload VNet')
param vnetName string

@description('Name for the private Load Balancer')
param lbName string = 'workload-lb'

@description('VM name for workload')
param vmName string = 'workload1-vm'

@description('Subnet name for VM')
param subnetName string = 'default'

@description('Admin username for VM')
param adminUsername string

@secure()
@description('Admin password for VM')
param adminPassword string

@description('Name for the private endpoint NIC')
param peNicName string = 'workload-pe-nic'

// Reference the workload VNet
resource workloadVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// Get subnet reference
var subnetRef = '${workloadVnet.id}/subnets/${subnetName}'

// Create NIC for VM
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'WorkloadPool')
            }
          ]
        }
      }
    ]
  }
}

// Create the VM
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Create a private Load Balancer
resource privateLB 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'PrivateIPConfig'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'WorkloadPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'PrivateIPConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'WorkloadPool')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'healthProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

// Add this resource to disable network policies on the subnet before creating Private Link Service
/* resource subnetNetworkPolicyDisable 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: workloadVnet.properties.subnets[0].properties.addressPrefix
    privateLinkServiceNetworkPolicies: 'Disabled'
    // Preserve existing properties
    //serviceEndpoints: workloadVnet.properties.subnets[0].properties.serviceEndpoints
    //delegations: workloadVnet.properties.subnets[0].properties.delegations
    networkSecurityGroup: workloadVnet.properties.subnets[0].properties.networkSecurityGroup
    //routeTable: workloadVnet.properties.subnets[0].properties.routeTable
  }
} */

// First create a Private Link Service in front of your Load Balancer
resource privateLinkService 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: 'workload-pls'
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'PrivateIPConfig')
      }
    ]
    ipConfigurations: [
      {
        name: 'pls-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetRef
          }
          primary: true
        }
      }
    ]
  }
  dependsOn: [
    privateLB
  ]
}

// REMOVE the existing resource reference completely
// resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
//   name: 'spoke2-vnet'
//   scope: resourceGroup('rg-az104vi')
// }

// UPDATE: Keep only the hardcoded string reference
/* var spoke2SubnetRef = '/subscriptions/c2ca6413-5b52-4008-8b75-04aad1b3ad09/resourceGroups/rg-az104vi/providers/Microsoft.Network/virtualNetworks/spoke2-vnet/subnets/default'
// Deploy the Private Endpoint in spoke2-vnet
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'workload-pe'
  location: location
  properties: {
    subnet: {
      id: spoke2SubnetRef
    }
    customNetworkInterfaceName: peNicName
    manualPrivateLinkServiceConnections: [
      {
        name: 'workload-plsc'
        properties: {
          privateLinkServiceId: privateLinkService.id
          groupIds: []
          requestMessage: 'please approve'
        }
      }
    ]
  }
} */

// Add DNS integration for better name resolution (recommended best practice)
/* resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.workload.contoso.local' // Use a domain relevant to your service
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-to-spoke2'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      // CHANGE: Use hardcoded reference instead of spoke2Vnet.id
      id: '/subscriptions/c2ca6413-5b52-4008-8b75-04aad1b3ad09/resourceGroups/rg-az104vi/providers/Microsoft.Network/virtualNetworks/spoke2-vnet'
    }
  }
} */

/* resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: privateEndpoint
  name: 'dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
} */

// Add Private Endpoint monitoring (best practice)
/* resource privateEndpointDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: privateEndpoint
  name: 'pe-diagnostics'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', 'YOUR-LOG-ANALYTICS') // Update with your workspace
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
  }
}
 */
// Outputs
output vmId string = vm.id
output lbId string = privateLB.id
//output privateEndpointId string = privateEndpoint.id
