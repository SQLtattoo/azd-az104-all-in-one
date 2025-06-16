@description('Name of the Key Vault')
param keyVaultName string

@description('Object ID to grant permissions to')
param objectId string

@description('Key permissions to grant')
param keyPermissions array = []

@description('Secret permissions to grant')
param secretPermissions array = []

@description('Certificate permissions to grant')
param certificatePermissions array = []

// Create access policy for the specified object ID
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        objectId: objectId
        tenantId: subscription().tenantId
        permissions: {
          keys: keyPermissions
          secrets: secretPermissions
          certificates: certificatePermissions
        }
      }
    ]
  }
}
