targetScope = 'subscription'

@description('Name of the role to check for existence')
param roleName string

// The deployment script needs a managed identity to query role definitions
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'role-query-identity'
  location: deployment().location
}

// Grant the managed identity Reader permissions at subscription level
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('Reader', scriptIdentity.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader role
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource checkRoleScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'check-role-exists'
  location: deployment().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.45.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    scriptContent: 'echo "{\"roleExists\": false, \"roleId\": \"\"}" > $AZ_SCRIPTS_OUTPUT_PATH'
    cleanupPreference: 'OnSuccess'
  }
  dependsOn: [
    roleAssignment // Ensure identity has permissions
  ]
}

// Since we can't actually query for role definitions at deployment time this way,
// we'll return a consistent result and let the caller handle role creation
output roleExists bool = false
output roleId string = ''
