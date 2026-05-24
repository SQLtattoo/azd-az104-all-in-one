// modules/connectionMonitor.bicep
// Deployed into NetworkWatcherRG (where the auto-created Network Watcher lives)
targetScope = 'resourceGroup'

@description('Name of the existing Network Watcher in this resource group')
param networkWatcherName string

@description('Resource ID of the Log Analytics Workspace to send results to')
param lawResourceId string

@description('Resource IDs of the two web-tier VMs to probe between')
param webVm0ResourceId string

@description('Resource IDs of the two web-tier VMs to probe between')
param webVm1ResourceId string

@description('Location for the Connection Monitor')
param location string

resource networkWatcher 'Microsoft.Network/networkWatchers@2021-05-01' existing = {
  name: networkWatcherName
}

resource connectionMonitor 'Microsoft.Network/networkWatchers/connectionMonitors@2022-05-01' = {
  name: 'az104-cm-web-backends'
  parent: networkWatcher
  location: location
  tags: { environment: 'demo', projectName: 'az104' }
  properties: {
    endpoints: [
      {
        name: 'web1-vm-source'
        type: 'AzureVM'
        resourceId: webVm0ResourceId
      }
      {
        name: 'web2-vm-dest'
        type: 'AzureVM'
        resourceId: webVm1ResourceId
      }
    ]
    testConfigurations: [
      {
        name: 'http-port80'
        protocol: 'Http'
        testFrequencySec: 60
        httpConfiguration: {
          method: 'GET'
          port: 80
          requestHeaders: []
          validStatusCodeRanges: [ '200-299' ]
          preferHTTPS: false
        }
        successThreshold: {
          checksFailedPercent: 10
          roundTripTimeMs: 1000
        }
      }
      {
        name: 'icmp-latency'
        protocol: 'Icmp'
        testFrequencySec: 30
        icmpConfiguration: {
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 200
        }
      }
    ]
    testGroups: [
      {
        name: 'web-backend-connectivity'
        disable: false
        sources: [ 'web1-vm-source' ]
        destinations: [ 'web2-vm-dest' ]
        testConfigurations: [ 'http-port80', 'icmp-latency' ]
      }
    ]
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: lawResourceId
        }
      }
    ]
  }
}
