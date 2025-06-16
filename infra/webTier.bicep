// infra/webTier.bicep
targetScope = 'resourceGroup'

// Import common settings - UPDATED PATH
module common 'common.bicep' = {
  name: 'web-common-params'
}

@description('Region for Web tier')
param location string

@description('Name of the spoke1 VNet')
param vnetName string

@description('Name for the Public Load Balancer')
param lbName string = 'web-lb'

@description('List of VM names to create behind the LB')
param vmNames array = [
  'web1-vm'
  'web2-vm'
]

@description('Subnet name to use for VMs and LB')
param subnetName string = 'default'

@secure()
param adminPassword string

@description('Admin username for the VMs')
param adminUsername string

// Define tags directly to avoid the module reference calculation error
param tags object = {
  environment: 'demo'
  projectName: 'az104'
}

// Define SKUs directly rather than using module outputs
var lbSku = 'Standard'
var pipSku = 'Standard'
var vmSize = 'Standard_B2ms'

// 1️⃣ Reference the spoke VNet
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

var subnetRef = '${spoke1Vnet.id}/subnets/${subnetName}'

// 2️⃣ Create a public IP for the LB with standardized SKU
resource lbPIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${lbName}-pip'
  location: location
  tags: tags
  sku: { name: pipSku }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 3️⃣ Deploy the Load Balancer
var frontendIPConfigId = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'LoadBalancerFrontEnd')
var backendPoolId = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'WebPool')
var healthProbeId = resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'healthProbe')

resource lb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  tags: tags
  sku: { name: lbSku }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: { id: lbPIP.id }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'WebPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'HttpRule'
        properties: {
          frontendIPConfiguration: { id: frontendIPConfigId }
          backendAddressPool:      { id: backendPoolId }
          protocol:                'Tcp'
          frontendPort:            80
          backendPort:             80
          enableFloatingIP:        false
          idleTimeoutInMinutes:    4
          probe: { id: healthProbeId }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol:          'Http'
          port:              80
          requestPath:       '/'
          intervalInSeconds: 5
          numberOfProbes:    2
        }
      }
    ]
    inboundNatRules: [for (vm, i) in vmNames: {
      name: 'RDP-VM${i + 1}'
      properties: {
        frontendIPConfiguration: { id: frontendIPConfigId }
        protocol: 'Tcp'
        frontendPort: 33891 + i
        backendPort: 3389
        idleTimeoutInMinutes: 4
        enableFloatingIP: false
      }
    }]
  }
}

// 4️⃣ Create VMs using the VM module
module webVMs 'modules/vm.bicep' = [for (vm, i) in vmNames: {
  name: '${vm}-deployment'
  params: {
    vmName: vm
    location: location
    subnetId: subnetRef
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    loadBalancerBackendPoolId: backendPoolId
    natRuleId: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', lbName, 'RDP-VM${i + 1}')
    tags: tags
    installIIS: true
  }
  dependsOn: [
    lb
  ]
}]
