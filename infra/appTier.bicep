// infra/appTier.bicep
targetScope = 'resourceGroup'

@description('Location for app tier resources')
param location string

@description('Name of the spoke2 VNet')
param vnetName string

@description('Name for the App Gateway')
param appGwName string = 'app-gateway'

@description('Name for the App Service')
param appServiceName string = 'app-service'

@description('List of VM names to create for app tier')
param vmNames array = [
  'vm1'
]

@description('Subnet name for VMs')
param vmSubnetName string = 'default'

@description('Subnet name for App Gateway')
param appGwSubnetName string = 'AppGwSubnet'

@description('Admin username for VMs')
param adminUsername string

@secure()
@description('Admin password for VMs')
param adminPassword string

// Reference the spoke2 VNet
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// Create Public IP for App Gateway
resource appGwPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${appGwName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${appGwName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Get subnet references
var vmSubnetRef = '${spoke2Vnet.id}/subnets/${vmSubnetName}'
var appGwSubnetRef = '${spoke2Vnet.id}/subnets/${appGwSubnetName}'

// Create NICs for VMs
resource nics 'Microsoft.Network/networkInterfaces@2021-05-01' = [for vm in vmNames: {
  name: '${vm}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vmSubnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}]

// Create VMs
resource vms 'Microsoft.Compute/virtualMachines@2021-07-01' = [for (vm, i) in vmNames: {
  name: vm
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
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
      computerName: vm
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

// Create App Service Plan and App Service
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${appServiceName}-plan'
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
}

resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: '${appServiceName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v4.8'
      healthCheckPath: '/'
    }
  }
}

resource appServiceIPRestriction 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: appService
  name: 'web'  // CORRECT resource name
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: '${appGwPip.properties.ipAddress}/32'
        action: 'Allow'
        priority: 100
        name: 'Allow-AppGw'
        description: 'Allow traffic from Application Gateway'
      }
      // Optional: Deny all other traffic
      {
        ipAddress: '0.0.0.0/0'
        action: 'Deny'
        priority: 2147483647
        name: 'Deny-All'
        description: 'Deny all other traffic'
      }
    ]
    // Optional: Add other web configuration properties
    http20Enabled: true
    minTlsVersion: '1.2'
    ftpsState: 'Disabled'
  }
}

// Application Gateway with App Service as backend
resource appGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGwName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: {
            id: appGwSubnetRef
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIP'
        properties: {
          publicIPAddress: {
            id: appGwPip.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'AppServicePool'
        properties: {
          backendAddresses: [
            {
              fqdn: appService.properties.defaultHostName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appservice-http-settings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGwName, 'appservice-probe')
          }
          trustedRootCertificates: [] // No need for custom root certs
        }
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwPublicFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    probes: [
      {
        name: 'appservice-probe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule-http'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'AppServicePool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'appservice-http-settings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
    }
  }
}

// Outputs
//output appGatewayId string = appGateway.id
//output appGatewayName string = appGateway.name
//output appGatewayPipId string = appGwPip.id
//output appServiceId string = appService.id
//output vmIds array = [for (vm, i) in vmNames: vms[i].id]
