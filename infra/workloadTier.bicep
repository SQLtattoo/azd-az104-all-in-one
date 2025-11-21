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

@description('VM size for workload tier VM')
param vmSize string = 'Standard_B2ms'

@description('Tags to apply to resources')
param tags object = {}

// Reference the workload VNet
resource workloadVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// Get subnet reference
var subnetRef = '${workloadVnet.id}/subnets/${subnetName}'

// Create a private Load Balancer FIRST
resource privateLB 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  tags: tags
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

// Create NIC for VM AFTER Load Balancer
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
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
              id: privateLB.properties.backendAddressPools[0].id
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
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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

// First create a Private Link Service in front of your Load Balancer
resource privateLinkService 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: 'workload-pls'
  location: location
  tags: tags
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: privateLB.properties.frontendIPConfigurations[0].id
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
}

// Outputs
output vmId string = vm.id
output lbId string = privateLB.id
//output privateEndpointId string = privateEndpoint.id
