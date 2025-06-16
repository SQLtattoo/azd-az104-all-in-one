targetScope = 'resourceGroup'

@description('Location for hub vnet resources')
param hubLocation string = 'ukSouth'

@description('Location for spoke1 vnet resources')
param spoke1Location string = 'ukSouth'

@description('Location for spoke2 vnet resources')
param spoke2Location string = 'northeurope'

@description('Location for workload vnet resources')
param workloadLocation string = 'uksouth'

@description('Administrator username for virtual machines')
param adminUsername string

@description('Administrator password for virtual machines')
@secure()
param adminPassword string

// Add parameter to control Bastion deployment
@description('Whether to deploy Bastion Host')
param deployBastion bool = true

// Add parameter to control VPN deployment
@description('Whether to deploy VPN Gateway')
param deployVpnGateway bool = true

// Add parameters for Key Vault and CMK
@description('Whether to deploy Key Vault for customer-managed keys demos')
param deployKeyVault bool = true 

@description('Object ID of the admin for Key Vault access')
param adminObjectId string = ''

@description('Whether to enable Customer-Managed Keys for storage encryption')
param enableCmkForStorage bool = false

param publicDnsZoneBase  string = 'contoso.com'
param privateDnsZoneBase string = 'contoso.local'
param vaultName          string = 'contoso-rsv'
param storageAccountPrefix string = 'staz104'

var hubVnetName = 'hub-vnet'
var spoke1VnetName = 'spoke1-vnet'
var spoke2VnetName = 'spoke2-vnet'
var workloadVnetName = 'workload-vnet'


module network 'network.bicep' = {
  name: 'vnets'
  params: {
    hublocation: hubLocation
    spoke1location: spoke1Location
    spoke2location: spoke2Location
    workloadlocation: workloadLocation
    hubVnetName: hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
    workloadVnetName: workloadVnetName
  }
}

module bastion 'bastion.bicep' = if (deployBastion) {
  name: 'bastion'
  params: {
    location:      hubLocation
    vnetName:      hubVnetName
    bastionName:   'hub-bastion'
    pipName:       'hub-bastion-pip'
  }
  dependsOn: [
    network 
  ]
}

module vpnGateway 'vpnGateway.bicep' = if (deployVpnGateway) {
  name: 'vpn'
  params: {
    location: hubLocation
    vnetName: hubVnetName
    gatewayPip: 'hub-vpn-pip'
    vpnGatewayName: 'hub-vpn-gateway'
  }
  dependsOn: [
    network  
  ]
} 

 module enableGatewayTransit 'enableGatewayTransit.bicep' = if (deployVpnGateway) {
  name: 'enableGatewayTransit'
  params: {
    hubVnetName:    hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
  }
  dependsOn: [
    vpnGateway 
  ]
}

module webTier 'webTier.bicep' = {
  name: 'webTier'
  params: {
    location:       hubLocation
    vnetName:       spoke1VnetName
    lbName:         'web-lb'
    vmNames:        [
      'web1-vm'
      'web2-vm'
    ]
    subnetName:     'default'
    adminUsername:  adminUsername
    adminPassword:  adminPassword
  }
  dependsOn: [
    //network 
  ]
}

module appTier 'appTier.bicep' = {
  name: 'appTier'
  params: {
    location: spoke2Location 
    vnetName: spoke2VnetName
    appGwName: 'app-gateway'
    vmNames: [
      'vm1'
    ]
    vmSubnetName: 'default'
    appGwSubnetName: 'AppGwSubnet' // Make sure this subnet exists in the spoke2-vnet
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    network 
  ]
}

module workloadTier 'workloadTier.bicep' = {
  name: 'workloadTier'
  params: {
    location: workloadLocation 
    vnetName: workloadVnetName
    lbName: 'workload-lb'
    vmName: 'workload1-vm'
    subnetName: 'default'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    network 
  ]
}

module consumerPe 'consumerPE.bicep' = {
  name: 'consumerPE'
  params: {
    location:           spoke2Location
    vnetName:           spoke2VnetName
    consumerSubnetName: 'default'
    peName:             'workload-pe'
    plsName:            'workload-pls'
  }
  dependsOn: [
    workloadTier
  ]
}

module shared 'sharedServices.bicep' = {
  name: 'sharedServices'
  params: {
    location: hubLocation
    publicDnsZoneBase: publicDnsZoneBase
    privateDnsZoneBase: privateDnsZoneBase
    vaultName: vaultName
    storageAccountPrefix: storageAccountPrefix
    deployKeyVault: deployKeyVault
    adminObjectId: adminObjectId
    enableCmkForStorage: enableCmkForStorage
  }
  dependsOn: [
    workloadTier
  ]
}

module dnsLinks 'dnsLinks.bicep' = {
  name: 'dnsLinks'
  params: {
    privateDnsZoneName:   shared.outputs.privateDnsZoneName
    hubVnetName:          hubVnetName
    spoke1VnetName:       spoke1VnetName
    spoke2VnetName:       spoke2VnetName
  }
  dependsOn: [
    network 
  ]
}

module vmss 'vmss.bicep' = {
  name: 'vmss'
  params: {
    location:       spoke2Location
    vnetName:       spoke2VnetName
    subnetName:     'default'
    vmSku:          'Standard_B2s'
    instanceCount:  2
    adminUsername:  adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    network
  ]
}

// Deploy governance components conditionally
module governance 'governance.bicep' = {
  name: 'governance-components'
  scope: subscription()
  params: {
    resourceGroupName: resourceGroup().name
    allowedLocations: [
      hubLocation
      spoke1Location
      spoke2Location
      workloadLocation
    ]
    allowedVmSizes: [
      'Standard_B2s' 
      'Standard_B2ms'
      'Standard_B4ms'
    ]
  }
}
