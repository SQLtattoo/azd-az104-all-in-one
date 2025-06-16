targetScope = 'resourceGroup'

@description('Azure region for all shared services')
param location           string = resourceGroup().location

// Base DNS zone names
@description('Base name for the public DNS zone (e.g. contoso.com)')
param publicDnsZoneBase string = 'contoso.com'

@description('Base name for the private DNS zone (e.g. contoso.local)')
param privateDnsZoneBase string = 'contoso.local'

// Generate 4-digit random suffix
var suffixDigits = substring(uniqueString(resourceGroup().id), 0, 4)

// Unique DNS zone names with 4-digit suffix
var uniquePublicDnsZoneName = replace(publicDnsZoneBase, '.com', '-${suffixDigits}.com')
var uniquePrivateDnsZoneName = replace(privateDnsZoneBase, '.local', '-${suffixDigits}.local')

@description('Name for the Recovery Services Vault')
param vaultName          string = 'contoso-rsv'

param storageAccountPrefix string = 'staz104'
var uniqueStorageName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'
var uniqueStorageAccountName = length(uniqueStorageName) > 24 ? substring(uniqueStorageName, 0, 24) : uniqueStorageName

@description('SKU for the Storage Account')
param storageSku         string = 'Standard_LRS'

@description('Whether to deploy Key Vault for customer-managed keys')
param deployKeyVault bool = false

@description('Object ID of the deployment principal for Key Vault access')
param adminObjectId string = ''

@description('Whether to enable Customer-Managed Keys for storage encryption')
param enableCmkForStorage bool = false

// 1️⃣ Public DNS Zone
resource publicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: uniquePublicDnsZoneName
  location: 'global'
}

// 2️⃣ Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: uniquePrivateDnsZoneName
  location: 'global'
}

// 3️⃣ Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2021-08-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

// Import common module for shared variables
module common 'common.bicep' = {
  name: 'shared-common-params'
}

// Fix: Define literal tags object since common module reference is used
var keyVaultTags = {
  project: 'AZ104 Demo'
  environment: 'demo'
  costCenter: 'Education'
  CostControl: 'ignore'
  SecurityControl: 'ignore'
}

// Debug the Key Vault deployment with more descriptive name and output
resource debugKeyVaultDeployment 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (deployKeyVault) {
  name: 'debug-keyvault-params'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.45.0'
    retentionInterval: 'P1D'
    scriptContent: 'echo "Key Vault deployment attempted with deployKeyVault=${deployKeyVault}, adminObjectId=${adminObjectId}"'
  }
}

// Key Vault for customer-managed keys - renamed to be clearer
resource keyVaultResource 'Microsoft.KeyVault/vaults@2022-07-01' = if (deployKeyVault) {
  name: 'kv-az104-${uniqueString(resourceGroup().id)}'
  location: location
  tags: keyVaultTags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enabledForDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    enableRbacAuthorization: !empty(adminObjectId) // Use RBAC if admin provided
    accessPolicies: !empty(adminObjectId) ? [
      {
        tenantId: subscription().tenantId
        objectId: adminObjectId
        permissions: {
          keys: ['all']
          secrets: ['all']
          certificates: ['all']
        }
      }
    ] : []
  }
}

// Create encryption key for storage
resource storageEncryptionKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = if (deployKeyVault && enableCmkForStorage) {
  parent: keyVaultResource
  name: 'storage-cmk'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'encrypt'
      'decrypt'
      'sign'
      'verify'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: true
    }
  }
}

// Storage Account - updated to use CMK if enabled
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: uniqueStorageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: enableCmkForStorage && deployKeyVault ? 'Microsoft.Keyvault' : 'Microsoft.Storage'
      keyvaultproperties: enableCmkForStorage && deployKeyVault ? {
        keyname: 'storage-cmk'
        keyvaulturi: keyVaultResource.properties.vaultUri
        keyversion: ''
      } : null
      services: {
        blob: { enabled: true }
        file: { enabled: true }
        table: { enabled: true }
        queue: { enabled: true }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Assign storage account MSI access to the Key Vault key if using CMK
module storageKeyAccess 'modules/keyvaultAccess.bicep' = if (deployKeyVault && enableCmkForStorage) {
  name: 'storage-key-access'
  params: {
    keyVaultName: keyVaultResource.name // Direct reference instead of module output
    objectId: storageAccount.identity.principalId
    keyPermissions: [
      'get'
      'wrapKey'
      'unwrapKey'
    ]
  }
  dependsOn: [
    keyVaultResource // Reference correct resource name
    storageAccount
  ]
}

// Export outputs
output publicDnsZoneName string = uniquePublicDnsZoneName
output privateDnsZoneName string = uniquePrivateDnsZoneName
output storageAccountName string = uniqueStorageAccountName
output keyVaultName string = deployKeyVault ? keyVaultResource.name : ''
output keyVaultUri string = deployKeyVault ? keyVaultResource.properties.vaultUri : ''
