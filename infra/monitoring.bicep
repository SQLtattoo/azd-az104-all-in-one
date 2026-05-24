// infra/monitoring.bicep
// ─────────────────────────────────────────────────────────────────────────────
// AZ-104 Monitoring & Observability Module
// Covers all 5 demo groups:
//   GROUP 1 — VM Insights (LAW, DCR, AMA, Dependency Agent)
//   GROUP 2 — Load Balancer Traffic (Diagnostic Settings, Metric Alerts)
//   GROUP 3 — Troubleshooting (Network Watcher, NW Agent, Connection Monitor)
//   GROUP 4 — App Gateway / WAF Insights (Diagnostic Settings)
//   GROUP 5 — Alerting (Action Group, Log Alerts, LB Metric Alerts, RSV)
// ─────────────────────────────────────────────────────────────────────────────
targetScope = 'resourceGroup'

// ─── Parameters ───────────────────────────────────────────────────────────────

@description('Primary location for monitoring resources (Log Analytics, DCR, etc.)')
param location string

@description('Toggle the entire monitoring feature set on/off')
param deployMonitoring bool = true

@description('Email address for Azure Monitor alert notifications')
param alertEmailAddress string = 'trainer@contoso.com'

@description('Location of Web-tier VMs — must match hubLocation in main.bicep')
param webVmLocation string = location

@description('Location of App-tier VM — must match spoke2Location in main.bicep')
param appVmLocation string = location

@description('Location of Workload-tier VM — must match workloadLocation in main.bicep')
param workloadVmLocation string = location

@description('Names of Web-tier VMs behind web-lb')
param webVmNames array = [ 'web1-vm', 'web2-vm' ]

@description('Names of App-tier VMs behind the App Gateway')
param appVmNames array = [ 'vm1' ]

@description('Name of the Workload-tier VM behind the private LB')
param workloadVmName string = 'workload1-vm'

@description('Name of the public Load Balancer (web tier)')
param webLbName string = 'web-lb'

@description('Name of the private Load Balancer (workload tier)')
param workloadLbName string = 'workload-lb'

@description('Name of the Application Gateway')
param appGwName string = 'app-gateway'

@description('Name of the Recovery Services Vault')
param vaultName string = 'contoso-rsv'

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 1 — VM Insights: Log Analytics Workspace + DCR + AMA + Dependency Agent
// ─────────────────────────────────────────────────────────────────────────────

var lawName = 'az104-law-${uniqueString(resourceGroup().id)}'

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (deployMonitoring) {
  name: lawName
  location: location
  tags: {
    environment: 'demo'
    projectName: 'az104'
    purpose: 'monitoring'
  }
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: false
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Enable the VMInsights solution in the workspace (shows the Map & Performance tabs)
resource vmInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (deployMonitoring) {
  name: 'VMInsights(${lawName})'
  location: location
  plan: {
    name: 'VMInsights(${lawName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: law.id
  }
}

// Enable the ServiceMap solution (powers the Dependency Map view)
resource serviceMapSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (deployMonitoring) {
  name: 'ServiceMap(${lawName})'
  location: location
  plan: {
    name: 'ServiceMap(${lawName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/ServiceMap'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: law.id
  }
}

// Data Collection Rule — VM Insights performance counters + Dependency Agent maps
resource vmInsightsDcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = if (deployMonitoring) {
  name: 'az104-vminsights-dcr'
  location: location
  tags: {
    environment: 'demo'
    projectName: 'az104'
    purpose: 'vminsights'
  }
  kind: 'Windows'
  properties: {
    description: 'VM Insights DCR - perf counters + Dependency Agent for AZ-104 demo'
    dataSources: {
      performanceCounters: [
        {
          streams: [ 'Microsoft-InsightsMetrics' ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [ '\\VmInsights\\DetailedMetrics' ]
          name: 'VMInsightsPerfCounters'
        }
      ]
      extensions: [
        {
          streams: [ 'Microsoft-ServiceMap' ]
          extensionName: 'DependencyAgent'
          extensionSettings: {}
          name: 'DependencyAgentDataSource'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: law.id
          name: 'lawDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [ 'Microsoft-InsightsMetrics' ]
        destinations: [ 'lawDestination' ]
      }
      {
        streams: [ 'Microsoft-ServiceMap' ]
        destinations: [ 'lawDestination' ]
      }
    ]
  }
}

// ── Web-tier VMs: AMA + Dependency Agent + DCR Association ────────────────────

resource existingWebVms 'Microsoft.Compute/virtualMachines@2022-03-01' existing = [for vmName in webVmNames: {
  name: vmName
}]

resource webVmAma 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vmName, i) in webVmNames: if (deployMonitoring) {
  name: 'AzureMonitorWindowsAgent'
  parent: existingWebVms[i]
  location: webVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]

resource webVmDepAgent 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vmName, i) in webVmNames: if (deployMonitoring) {
  name: 'DependencyAgentWindows'
  parent: existingWebVms[i]
  location: webVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.10'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      enableAMA: 'true'
    }
  }
  dependsOn: [ webVmAma[i] ]
}]

resource webVmNwAgent 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vmName, i) in webVmNames: if (deployMonitoring) {
  name: 'NetworkWatcherAgentWindows'
  parent: existingWebVms[i]
  location: webVmLocation
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentWindows'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
  }
}]

resource webVmDcrAssoc 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for (vmName, i) in webVmNames: if (deployMonitoring) {
  name: 'vminsights-dcra'
  scope: existingWebVms[i]
  properties: {
    dataCollectionRuleId: vmInsightsDcr.id
    description: 'VM Insights DCR association'
  }
  dependsOn: [ webVmAma[i] ]
}]

// ── App-tier VM: AMA + Dependency Agent + DCR Association ─────────────────────

resource existingAppVms 'Microsoft.Compute/virtualMachines@2022-03-01' existing = [for vmName in appVmNames: {
  name: vmName
}]

resource appVmAma 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vmName, i) in appVmNames: if (deployMonitoring) {
  name: 'AzureMonitorWindowsAgent'
  parent: existingAppVms[i]
  location: appVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]

resource appVmDepAgent 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vmName, i) in appVmNames: if (deployMonitoring) {
  name: 'DependencyAgentWindows'
  parent: existingAppVms[i]
  location: appVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.10'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      enableAMA: 'true'
    }
  }
  dependsOn: [ appVmAma[i] ]
}]

resource appVmDcrAssoc 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for (vmName, i) in appVmNames: if (deployMonitoring) {
  name: 'vminsights-dcra'
  scope: existingAppVms[i]
  properties: {
    dataCollectionRuleId: vmInsightsDcr.id
    description: 'VM Insights DCR association'
  }
  dependsOn: [ appVmAma[i] ]
}]

// ── Workload-tier VM: AMA + Dependency Agent + DCR Association ────────────────

resource existingWorkloadVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: workloadVmName
}

resource workloadVmAma 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (deployMonitoring) {
  name: 'AzureMonitorWindowsAgent'
  parent: existingWorkloadVm
  location: workloadVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource workloadVmDepAgent 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (deployMonitoring) {
  name: 'DependencyAgentWindows'
  parent: existingWorkloadVm
  location: workloadVmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.10'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      enableAMA: 'true'
    }
  }
  dependsOn: [ workloadVmAma ]
}

resource workloadVmDcrAssoc 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (deployMonitoring) {
  name: 'vminsights-dcra'
  scope: existingWorkloadVm
  properties: {
    dataCollectionRuleId: vmInsightsDcr.id
    description: 'VM Insights DCR association'
  }
  dependsOn: [ workloadVmAma ]
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 5 — Action Group (shared by Groups 2, 3, 4, 5 alert rules)
// ─────────────────────────────────────────────────────────────────────────────

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (deployMonitoring) {
  name: 'az104-class-ag'
  location: 'global'
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    groupShortName: 'AZ104Class'
    enabled: true
    emailReceivers: [
      {
        name: 'TrainerEmail'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 2 — LB Diagnostic Settings + Metric Alerts
// ─────────────────────────────────────────────────────────────────────────────

resource existingWebLb 'Microsoft.Network/loadBalancers@2021-05-01' existing = {
  name: webLbName
}

resource existingWorkloadLb 'Microsoft.Network/loadBalancers@2021-05-01' existing = {
  name: workloadLbName
}

resource webLbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployMonitoring) {
  name: 'web-lb-diagnostics'
  scope: existingWebLb
  properties: {
    workspaceId: law.id
    // Standard LB has no supported log categories — metrics only
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource workloadLbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployMonitoring) {
  name: 'workload-lb-diagnostics'
  scope: existingWorkloadLb
  properties: {
    workspaceId: law.id
    // Standard LB has no supported log categories — metrics only
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Metric Alert — LB backend health probe dipping below 100% (at least one VM unhealthy)
resource lbHealthAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (deployMonitoring) {
  name: 'alert-web-lb-unhealthy-backend'
  location: 'global'
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    description: 'Fires when at least one web-lb backend VM fails its health probe. Great for live troubleshooting demo.'
    severity: 2
    enabled: true
    scopes: [ existingWebLb.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'BackendHealthCheck'
          metricName: 'DipAvailability'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      { actionGroupId: actionGroup.id }
    ]
  }
}

// Metric Alert — SNAT connection count threshold (shows SNAT exhaustion concept)
resource lbSnatAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (deployMonitoring) {
  name: 'alert-web-lb-snat-connections'
  location: 'global'
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    description: 'Demo alert: fires when SNAT connection count exceeds threshold — use to explain SNAT exhaustion.'
    severity: 3
    enabled: true
    scopes: [ existingWebLb.id ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'SnatConnections'
          metricName: 'SnatConnectionCount'
          operator: 'GreaterThan'
          threshold: 50
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      { actionGroupId: actionGroup.id }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 4 — App Gateway / WAF Diagnostic Settings
// ─────────────────────────────────────────────────────────────────────────────

resource existingAppGw 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  name: appGwName
}

resource appGwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployMonitoring) {
  name: 'appgw-diagnostics'
  scope: existingAppGw
  properties: {
    workspaceId: law.id
    logs: [
      {
        // Backend request/response details, latency, client IP, URL, response code
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        // WAF rule firings — blocked/detected requests
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
      {
        // Capacity units, throughput
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 5 — Log Alert Rules (VM Heartbeat, CPU, Backup Job Failure)
// ─────────────────────────────────────────────────────────────────────────────

// Scheduled Query Alert — VM Heartbeat Loss (VM stopped/unreachable)
resource vmHeartbeatAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (deployMonitoring) {
  name: 'alert-vm-heartbeat-loss'
  location: location
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    description: 'Fires when a VM stops sending heartbeats to Log Analytics — use to demo VM availability monitoring.'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [ law.id ]
    criteria: {
      allOf: [
        {
          query: 'Heartbeat | summarize LastHeartbeat = max(TimeGenerated) by Computer | where LastHeartbeat < ago(5m)'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            minFailingPeriodsToAlert: 1
            numberOfEvaluationPeriods: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [ actionGroup.id ]
    }
  }
}

// Scheduled Query Alert — Sustained high CPU across any VM
resource vmCpuAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (deployMonitoring) {
  name: 'alert-vm-high-cpu'
  location: location
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    description: 'Fires when average CPU across any VM exceeds 85% for 10 minutes. Demo: stress-test a VM to trigger it.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [ law.id ]
    criteria: {
      allOf: [
        {
          // TimeGenerated must be in the output when numberOfEvaluationPeriods > 1
          query: 'InsightsMetrics | where Namespace == "Processor" and Name == "UtilizationPercentage" | summarize AvgCPU = avg(Val) by Computer, bin(TimeGenerated, 5m) | where AvgCPU > 85'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            minFailingPeriodsToAlert: 2
            numberOfEvaluationPeriods: 2
          }
        }
      ]
    }
    actions: {
      actionGroups: [ actionGroup.id ]
    }
  }
}

// Recovery Services Vault — Diagnostic Settings (send backup job logs to LAW)
resource existingRsv 'Microsoft.RecoveryServices/vaults@2021-08-01' existing = {
  name: vaultName
}

resource rsvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployMonitoring) {
  name: 'rsv-diagnostics'
  scope: existingRsv
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'AzureBackupReport'
        enabled: true
      }
      {
        category: 'CoreAzureBackup'
        enabled: true
      }
      {
        category: 'AddonAzureBackupJobs'
        enabled: true
      }
    ]
  }
}

// Activity Log Alert — Backup job failure
resource backupJobFailureAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = if (deployMonitoring) {
  name: 'alert-backup-job-failure'
  location: 'global'
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    description: 'Fires when a Recovery Services Vault backup job fails. Demo: trigger a failed backup to show alerting lifecycle.'
    enabled: true
    scopes: [ resourceGroup().id ]
    condition: {
      allOf: [
        {
          // 'Administrative' covers ARM control-plane operations (backup job writes)
          // 'ServiceHealth' is for Microsoft service incidents — wrong category here
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.RecoveryServices/vaults/backupJobs/write'
        }
        {
          field: 'status'
          equals: 'Failed'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
          webhookProperties: {}
        }
      ]
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP 3 — Network Watcher + Connection Monitor
// ─────────────────────────────────────────────────────────────────────────────

// Connection Monitor must live under the Network Watcher which Azure auto-creates in NetworkWatcherRG.
// A separate module scoped to NetworkWatcherRG is required — Bicep cannot deploy child resources
// cross-scope inline.
module connectionMonitor 'modules/connectionMonitor.bicep' = if (deployMonitoring) {
  name: 'connectionMonitor'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    networkWatcherName: 'NetworkWatcher_${location}'
    lawResourceId:      law.id
    webVm0ResourceId:   resourceId('Microsoft.Compute/virtualMachines', webVmNames[0])
    webVm1ResourceId:   resourceId('Microsoft.Compute/virtualMachines', webVmNames[1])
    location:           location
  }
  dependsOn: [
    webVmNwAgent
  ]
}

// ─────────────────────────────────────────────────────────────────────────────
// Outputs — consume in main.bicep or demo scripts
// ─────────────────────────────────────────────────────────────────────────────

output logAnalyticsWorkspaceId string = deployMonitoring ? law.id : ''
output logAnalyticsWorkspaceName string = deployMonitoring ? law.name : ''
output dcrId string = deployMonitoring ? vmInsightsDcr.id : ''
output actionGroupId string = deployMonitoring ? actionGroup.id : ''
