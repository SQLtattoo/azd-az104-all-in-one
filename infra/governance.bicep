targetScope = 'subscription'

@description('Whether to deploy governance features')
param deployGovernance bool = false

@description('Resource group name for scoping')
param resourceGroupName string

@description('List of allowed locations for resources')
param allowedLocations array

@description('List of allowed VM sizes')
param allowedVmSizes array = [
  'Standard_B2s'
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D2s_v3'
  'Standard_D4s_v3'
]

@description('Role definition name - change this if you need to create a new role')
param roleName string = 'VM Support Engineer'

// Generate a unique name for the role to avoid conflicts
var uniqueRoleName = '${roleName} (${resourceGroupName})'

// Create Custom RBAC Role: VM Support Engineer
resource vmSupportRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (deployGovernance) {
  name: guid(uniqueRoleName, subscription().subscriptionId)
  properties: {
    roleName: uniqueRoleName
    description: 'Can manage VMs and open Microsoft support tickets'
    type: 'CustomRole'
    assignableScopes: [
      subscription().id // Use subscription scope for broader visibility
    ]
    permissions: [
      {
        actions: [
          // VM Contributor permissions
          'Microsoft.Compute/availabilitySets/*'
          'Microsoft.Compute/virtualMachines/*'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/disks/write'
          'Microsoft.Network/networkInterfaces/*'
          'Microsoft.Network/networkSecurityGroups/join/action'
          'Microsoft.Network/virtualNetworks/subnets/join/action'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Storage/storageAccounts/listKeys/action'
          'Microsoft.Storage/storageAccounts/read'
          
          // Support ticket actions
          'Microsoft.Support/*'
        ]
        notActions: [
          // Restrict certain VM operations
          'Microsoft.Compute/virtualMachines/delete'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

// Create Policy Initiative Definition for VM Governance
resource vmGovernanceInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = if (deployGovernance) {
  name: 'vm-governance-initiative-${uniqueString(subscription().id, resourceGroupName)}'
  properties: {
    displayName: 'Virtual Machine Governance for ${resourceGroupName}'
    description: 'Initiative to enforce VM governance including allowed locations and VM sizes'
    metadata: {
      category: 'Compute'
      version: '1.0.0'
    }
    policyDefinitions: [
      // Allowed locations policy
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
        policyDefinitionReferenceId: 'allowedLocations'
        parameters: {
          listOfAllowedLocations: {
            value: allowedLocations
          }
        }
      }
      // Allowed VM SKUs policy
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3'
        policyDefinitionReferenceId: 'allowedVMSKUs'
        parameters: {
          listOfAllowedSKUs: {
            value: allowedVmSizes
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'
        policyDefinitionReferenceId: 'requiredTags'
        parameters: {
          tagName: {  
            value: 'environment'
          }
        }
      }
      // Audit VMs that don't use managed disks
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
        policyDefinitionReferenceId: 'auditUnmanagedDisks'
        parameters: {}
      }
    ]
  }
}

// Output the role ID directly
output vmSupportRoleId string = deployGovernance ? vmSupportRole.id : ''
output vmGovernanceInitiativeId string = deployGovernance ? vmGovernanceInitiative.id : ''
