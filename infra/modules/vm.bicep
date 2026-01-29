@description('VM Name')
param vmName string

@description('Location for resources')
param location string

@description('Subnet ID for network interface')
param subnetId string

@description('Admin username')
param adminUsername string

@secure()
@description('Admin password')
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_B2s_v2'

@description('Load balancer backend pool ID (optional)')
param loadBalancerBackendPoolId string = ''

@description('NAT rule ID (optional)')
param natRuleId string = ''

@description('Tags to apply to resources')
param tags object = {}

@description('OS image parameters')
param imageReference object = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}

@description('Whether to install IIS on the VM')
param installIIS bool = true

@description('Custom HTML content for default.htm')
param customWebContent string = ''

// Create NIC
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
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: !empty(loadBalancerBackendPoolId) ? [
            {
              id: loadBalancerBackendPoolId
            }
          ] : null
          loadBalancerInboundNatRules: !empty(natRuleId) ? [
            {
              id: natRuleId
            }
          ] : null
        }
      }
    ]
  }
}

// Create VM
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
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
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
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

resource iisExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01'= if (installIIS) {
  parent: vm
  name: 'InstallIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: !empty(customWebContent) 
        ? 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Remove-Item -Path C:\\inetpub\\wwwroot\\iisstart.htm -Force -ErrorAction SilentlyContinue; Set-Content -Path C:\\inetpub\\wwwroot\\default.htm -Value \'${customWebContent}\'"'
        : 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Remove-Item -Path C:\\inetpub\\wwwroot\\iisstart.htm -Force -ErrorAction SilentlyContinue; Set-Content -Path C:\\inetpub\\wwwroot\\default.htm -Value \'<h1>Hello from ${vmName}!</h1><p>Server: ${vmName}</p><p>Location: ${location}</p><p>Deployment Time: $(Get-Date)</p>\'"'
    }
  }
}

output vmId string = vm.id
output nicId string = nic.id
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress

