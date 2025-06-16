targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Virtual Network')
param vnetName string = 'spoke2-vnet'

@description('Name of the subnet to deploy VMSS into')
param subnetName string = 'default'

@description('VM SKU for the scale set')
param vmSku string = 'Standard_B2s'

@description('Number of VM instances')
param instanceCount int = 2

@description('Admin username for VM')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for VM')
param adminPassword string

// Reference existing VNet and Subnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

var subnetId = '${vnet.id}/subnets/${subnetName}'

@description('Name of the VM Scale Set')
var vmssName = 'vmssaz104'

// VM Scale Set resource
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-07-01' = {
  name: vmssName
  location: location
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    // required for flexible orchestration
    platformFaultDomainCount: 1
    orchestrationMode: 'Flexible'
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
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
        computerNamePrefix: vmssName
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkApiVersion: '2021-05-01'  // Add this line at the networkProfile level
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}
