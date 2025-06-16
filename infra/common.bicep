// Common parameters and variables for AZ104 demo environment
targetScope = 'resourceGroup'

// Locations
@description('Primary location for hub resources')
param primaryLocation string = 'ukSouth'

@description('Secondary location for spoke2 resources')
param secondaryLocation string = 'northeurope'

@description('Location for workload resources')
param workloadLocation string = 'eastus2'

// Resource naming
@description('Project prefix for resource naming')
param prefix string = 'az104'

@description('Environment name for resource naming')
param env string = 'demo'

@description('Azure region for resources')
param location string = resourceGroup().location

// Network address spaces
var networkAddressSpace = {
  hub: '10.1.0.0/16'
  spoke1: '10.2.0.0/16'
  spoke2: '10.3.0.0/16'
  workload: '10.4.0.0/16'
}

// Standard subnet definitions
var subnets = {
  bastion: {
    name: 'AzureBastionSubnet'
    prefix: '10.1.1.0/26'
  }
  gateway: {
    name: 'GatewaySubnet'
    prefix: '10.1.2.0/27'
  }
  management: {
    name: 'hub-mgmt'
    prefix: '10.1.3.0/24'
  }
  default: {
    spoke1Prefix: '10.2.1.0/24'
    spoke2Prefix: '10.3.1.0/24'
    workloadPrefix: '10.4.1.0/24'
  }
  appGateway: {
    name: 'AppGwSubnet'
    prefix: '10.3.2.0/24'
  }
}

// VM sizing
var vmSizes = {
  small: 'Standard_B2s'
  medium: 'Standard_B2ms'
  large: 'Standard_B4ms'
}

// Resource SKUs
var skus = {
  storageAccount: 'Standard_LRS'
  bastion: 'Standard'
  vpnGateway: 'VpnGw1'
  appGateway: 'WAF_v2'
  loadBalancer: 'Standard'
  publicIP: 'Standard'
}

// Common tags
var tags = {
  project: 'AZ104 Demo'
  environment: env
  costCenter: 'Education'
  CostControl: 'ignore'
  SecurityControl: 'ignore'
}

// Outputs for consumption by other modules
output locations object = {
  primary: primaryLocation
  secondary: secondaryLocation
  workload: workloadLocation
}
output networkAddressSpace object = networkAddressSpace
output subnets object = subnets
output vmSizes object = vmSizes
output skus object = skus
output tags object = tags
output prefix string = prefix
output env string = env
output location string = location
output defaultTags object = tags
