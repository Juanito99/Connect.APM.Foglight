param($sourceId,$managedEntityId)

$api = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

#region PREWORK Disabling the certificate validations
if ("TrustAllCertsPolicy" -as [type]) {
	$foo = 'already exist'
} else {
add-type -TypeDefinition @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
}
#endregion PREWORK


$classFoglightMonitoringServer          = Get-SCOMClass -Name 'Connect.APM.Foglight.MonitoringServer'
$classFoglightMonitoringServerInstances = Get-SCOMClassInstance -Class $classFoglightMonitoringServer
$foglightMonitoringServer               = $classFoglightMonitoringServerInstances.'[Microsoft.Windows.Computer].PrincipalName'.Value

$apmServerAuthToken                     = $classFoglightMonitoringServerInstances.'[Connect.APM.Foglight.MonitoringServer].APMServerAuthToken'.Value
$apmServerURL                           = $classFoglightMonitoringServerInstances.'[Connect.APM.Foglight.MonitoringServer].APMServerURL'.Value

$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',110,4,"DiscoverDBORelations.ps1 - Starting with APM Server query $($apmServerURL)")


Function Get-DBOFromFoglightWebService {

	param(
		[ref]$outList,
		[string]$qryItem,
		[string]$apmServerURL,
		[string]$apmServerAuthToken
	)

	$rtn = $false	
		
	$url     = $apmServerURL + '/api/v1/topology/query?showTopologyTypeLocalProperties=true'
	$headers = @{    
		'Auth-Token' = $apmServerAuthToken
		'Accept'     = 'application/json'
	}

	$tmpList = New-Object -TypeName System.Collections.ArrayList

	$generalProps = @(
		'uniqueId'		
		'longName'
		'isBlackedOut'
		'localState'
		'aggregateState'
		'alarmTotalCount'
		'alarmAggregateTotalCount'	
	)

	$serverProps = @(
		'uniqueId'		
		'longName'
		'isBlackedOut'
		'localState'
		'aggregateState'
		'alarmTotalCount'
		'alarmAggregateTotalCount'	
		'aggregateAlarms'
		'active_Host'
	)

	$tableSpaceProps = @(
		'uniqueId'		
		'longName'
		'isBlackedOut'
		'localState'
		'aggregateState'
		'alarmTotalCount'
		'alarmAggregateTotalCount'
		'tablespace_name'	
		'status'
		'contents'
		'retention'
		'block_size'
	)

	$agentModelProps = @(
		'uniqueId'		
		'longName'
		'isBlackedOut'
		'localState'
		'aggregateState'
		'alarmTotalCount'
		'alarmAggregateTotalCount'
		'agentVersion'
		'hostName'
		'agentName'
		'build'		
		'type'
	)

	switch ($qryItem) {
		"Servers"  {			
			
			$body = @{ "queryText" = "!DBO_Servers"	} | ConvertTo-Json
			$dboServersRaw = ''
			$dboServersRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboServersRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"Query $($qryItem), returned $($dboServersRaw.data.count) objects.")
				$dboServersRaw.data | ForEach-Object {
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $serverProps
					if ($tmp) {		
						if ($tmp.active_host.name) {
							$ativeHost = $tmp.active_host.name
						} else {
							$activeHost = 'Not defined'
						}
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$dboObj = [PSCustomObject] @{							
							  [string]'uniqueId'         = $tmp.uniqueId -replace '-',''							  
							  [string]'longName'         = $tmp.longName
							  [string]'dbName'           = $dbName
							  [string]'isBlackedOut'     = if ($tmp.isBlackedOut -eq 'false') { 'yes' } else { 'no' }
							  'localState'               = $tmp.localState
							  'aggregateState'           = $tmp.aggregateState
							  'alarmTotalCount'          = $tmp.alarmTotalCount
							  'alarmAggregateTotalCount' = $tmp.alarmAggregateTotalCount
							  'activeHost'               = $activeHost
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				}
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboServersRaw.data.count) objects! Check query.")
			}
			break
		} #end Servers   
		"Database"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboDatabaseRaw = ''
			$dboDatabaseRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboDatabaseRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',101,4,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects.")
				$dboDatabaseRaw.data | ForEach-Object {
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $generalProps
					if ($tmp) {		
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$dboObj = [PSCustomObject] @{
							  [string]'uniqueId'         = $tmp.uniqueId -replace '-',''							  
							  [string]'longName'         = $tmp.longName
							  [string]'dbName'           = $dbName
							  [string]'isBlackedOut'     = if ($tmp.isBlackedOut -eq 'false') { 'yes' } else { 'no' }
							  'localState'               = $tmp.localState
							  'aggregateState'           = $tmp.aggregateState
							  'alarmTotalCount'          = $tmp.alarmTotalCount
							  'alarmAggregateTotalCount' = $tmp.alarmAggregateTotalCount
						}
						if ($dbName -ne '' -and $dbname -match '[a-zA-Z]{1,}') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects! Check query.")
			}
			break
		} #end Database
		"Listener"  {			
			
			$body = @{ "queryText" = "!DBO_Listener_Status" } | ConvertTo-Json
			$dboListenerStatusRaw = ''
			$dboListenerStatusRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboListenerStatusRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects.")
				$dboListenerStatusRaw.data | ForEach-Object {
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $generalProps
					if ($tmp) {		
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$dboObj = [PSCustomObject] @{
							  [string]'uniqueId'         = $tmp.uniqueId -replace '-',''							  
							  [string]'longName'         = $tmp.longName
							  [string]'dbName'           = $dbName
							  [string]'isBlackedOut'     = if ($tmp.isBlackedOut -eq 'false') { 'yes' } else { 'no' }
							  'localState'               = $tmp.localState
							  'aggregateState'           = $tmp.aggregateState
							  'alarmTotalCount'          = $tmp.alarmTotalCount
							  'alarmAggregateTotalCount' = $tmp.alarmAggregateTotalCount
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects! Check query.")
			}
			break
		} #end Listener
		"DB-System"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboSystemRaw = ''
			$dboSystemRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json
			
			if ($dboSystemRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects.")
				$dboSystemRaw.data | ForEach-Object {
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $generalProps
					if ($tmp) {		
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$uniID  =  $tmp.uniqueId -replace '-',''
						if ($uniID -notMatch '-Sys') {
							$uniID  = $uniID + '-Sys'
						}						
						$dboObj = [PSCustomObject] @{
							  [string]'uniqueId'         = $uniID
							  [string]'longName'         = $tmp.longName + '_Long'
							  [string]'dbName'           = $dbName							  
						}
						if ($dbName -ne '' -and $dbname -match '[a-zA-Z]{1,}') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects! Check query.")
			}
			break
		} #end DB-System
		"Tablespace"  {			
			
			$body = @{ "queryText" = "!DBO_Tablespace" } | ConvertTo-Json
			$dboTableSpaceRaw = ''
			$dboTableSpaceRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboTableSpaceRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects.")
				$dboTableSpaceRaw.data | ForEach-Object {					
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $tableSpaceProps
					if ($tmp) {		
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$dboObj = [PSCustomObject] @{
							  [string]'uniqueId'         = $tmp.uniqueId -replace '-',''							  
							  [string]'longName'         = $tmp.longName
							  [string]'dbName'           = $dbName
							  [string]'isBlackedOut'     = if ($tmp.isBlackedOut -eq 'false') { 'yes' } else { 'no' }
							  'localState'               = $tmp.localState
							  'aggregateState'           = $tmp.aggregateState
							  'alarmTotalCount'          = $tmp.alarmTotalCount
							  'alarmAggregateTotalCount' = $tmp.alarmAggregateTotalCount
							  [string]'tableSpaceName'   = $tmp.tablespace_Name
							  [string]'status'           = $tmp.status
							  [string]'contents'         = $tmp.contents
							  [string]'retention'        = $tmp.retention
							  'blocksize'                = $tmp.block_size			  
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				}

			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects! Check query.")
			}
			break
		} #end Tablespace
		"Agent"  {			
			
			$body = @{ "queryText" = "!DBO_Agent_Model" } | ConvertTo-Json
			$dboAgentModelRaw = ''
			$dboAgentModelRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboAgentModelRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects.")
				$dboAgentModelRaw.data | ForEach-Object {
					$tmp = ''
					$tmp = $_.properties | Select-Object -Property $agentModelProps
					if ($tmp) {		
						$dbName = ''
						$dbName = [Regex]::Matches($($tmp.longName),'[a-zA-Z]{5,}[a-zA-Z]{1,}[a-zA-Z]{1,}[dbDB]{2}').Value
						$dboObj = [PSCustomObject] @{
							  [string]'uniqueId'         = $tmp.uniqueId -replace '-',''							  
							  [string]'longName'         = $tmp.longName
							  [string]'dbName'           = $dbName
							  [string]'isBlackedOut'     = if ($tmp.isBlackedOut -eq 'false') { 'yes' } else { 'no' }
							  'localState'               = $tmp.localState
							  'aggregateState'           = $tmp.aggregateState
							  'alarmTotalCount'          = $tmp.alarmTotalCount
							  'alarmAggregateTotalCount' = $tmp.alarmAggregateTotalCount
							  [string]'agentVersion'     = $tmp.agentVersion
							  [string]'agentName'        = $tmp.agentName
							  [string]'build'            = $tmp.build
							  [string]'monitoringHost'   = $tmp.hostName
							  [string]'type'             = $tmp.type 
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects! Check query.")
			}
			break
		} #end Agent

	} #end switch ($qryItem)
	
	$outList.Value = $tmpList
	
	if ($tmpList.Count -gt 1) {
		$rtn = $true
	} else {
		$rtn = $false
	}

	$rtn

} #end Function Get-DBOFromFoglightWebService 


$apmServerName = $apmServerURL  -replace ':[\d]{1,}',''
$apmServerName = $apmServerName -replace '(?i)https?://',''

if (Test-Connection -ComputerName $apmServerName -Count 2 -Quiet) {

	$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,4,"DiscoverDBORelations.ps1 - APM Server $($apmServerURL) is reachable via PING.")
		
	$dboServers = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'Servers' -apmServerURL 	$apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboServers)

	$dboDatabase = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'Database' -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboDatabase)

	$dboDBSystem = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'DB-System' -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboDBSystem)

	$dboTableSpace = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'Tablespace' -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboTableSpace)

	$dboAgent = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'Agent' -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboAgent)

	$dboListener = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem 'Listener' -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboListener)
	
	$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',115,2,"DiscoverDBORelations.ps1 - APM DBOSystem.Count $($dboDBSystem.count) ")
	
	foreach ($dbSysItem in $dboDBSystem) {

		$dbName = $dbSysItem.dbName

		$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',116,2,"DiscoverDBORelations.ps1 - LOOP dbName $($dbName) --> dbSysItem $($dbSysItem) ")

		$displayName = "DB-System-$($dbName)-(Foglight)"
		
		$srcInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.DatabaseSystem']$")
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.DatabaseSystem']/uniqueId$", $dbSysItem.uniqueId)
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $dbSysItem.longName)
		$srcInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
		$discoveryData.AddInstance($srcInstance)

		$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
		$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $foglightMonitoringServer)			
		$discoveryData.AddInstance($healthInstance)		
				
		$dbInstances = ''
		$dbInstances = $dboDatabase | Where-Object {$_.dbName -eq $dbName}
		
		foreach ($itemDB in $dbInstances) {
			$displayName = "Database-$($dbName)-(Foglight)"
			$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Database']$")
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Database']/uniqueId$", $itemDB.uniqueId)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $itemDB.longName)		
			$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($targetInstance)
	
			$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Connect.APM.Foglight.DatabaseSystemHostsDatabase']$")
			$relInstance.Source = $srcInstance
			$relInstance.Target = $targetInstance
			$discoveryData.AddInstance($relInstance)

			$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
			$relHealthInstance.Source = $healthInstance
			$relHealthInstance.Target = $targetInstance									
			$discoveryData.AddInstance($relHealthInstance)
		} #end foreach ($dbi in $dbInstances)

		$serverInstances = ''
		$serverInstances = $dboServers | Where-Object {$_.dbName -eq $dbName}

		foreach ($itmServer in $serverInstances) {
			$displayName = "Servers-$($dbName)-(Foglight)"
			$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Server']$")
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Server']/uniqueId$", $itmServer.uniqueId)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Server']/activeHost$", $itmServer.activeHost)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $itmServer.longName)		
			$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($targetInstance)
	
			$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Connect.APM.Foglight.DatabaseSystemHostsServer']$")
			$relInstance.Source = $srcInstance
			$relInstance.Target = $targetInstance
			$discoveryData.AddInstance($relInstance)

			$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
			$relHealthInstance.Source = $healthInstance
			$relHealthInstance.Target = $targetInstance									
			$discoveryData.AddInstance($relHealthInstance)
		}  #end foreach ($dboServer in serverInstances)

		$listenerInstances = ''
		$listenerInstances = $dboListener | Where-Object {$_.dbName -eq $dbName}

		foreach ($itmListener in $listenerInstances) {
			$displayName = "Listener-$($dbName)-(Foglight)"
			$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Listener']$")
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Listener']/uniqueId$", $itmListener.uniqueId)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $itmListener.longName)		
			$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($targetInstance)
	
			$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Connect.APM.Foglight.DatabaseSystemHostsListener']$")
			$relInstance.Source = $srcInstance
			$relInstance.Target = $targetInstance
			$discoveryData.AddInstance($relInstance)

			$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
			$relHealthInstance.Source = $healthInstance
			$relHealthInstance.Target = $targetInstance									
			$discoveryData.AddInstance($relHealthInstance)
		}  #end foreach ($itmListener in $listenerInstances)

		
		$agentInstances = ''
		$agentInstances = $dboAgent | Where-Object {$_.dbName -eq $dbName}

		foreach ($itmAgent in $agentInstances) {
			$displayName = "Agent-$($dbName)-(Foglight)"
			$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']$")
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/uniqueId$", $itmAgent.uniqueId)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $itmAgent.longName)					
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/agentVersion$", $itmAgent.agentVersion)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/agentName$", $itmAgent.agentName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/build$", $itmAgent.build)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/monitoringHost$", $itmAgent.monitoringHost)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/type$", $itmAgent.type)
			$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($targetInstance)
	
			$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Connect.APM.Foglight.DatabaseSystemHostsAgent']$")
			$relInstance.Source = $srcInstance
			$relInstance.Target = $targetInstance
			$discoveryData.AddInstance($relInstance)

			$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
			$relHealthInstance.Source = $healthInstance
			$relHealthInstance.Target = $targetInstance									
			$discoveryData.AddInstance($relHealthInstance)
		}  #end foreach ($itmAgemt in $agentInstances)
		
	} #end foreach ($dboItm in $dboList)

	foreach ($dboDBItem in $dboDatabase) {

		$dbName = $dboDBItem.dbName

		$displayName = "Database-$($dbName)-(Foglight)"
		$srcInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Database']$")
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Database']/uniqueId$", $dboDBItem.uniqueId)
		$srcInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $dboDBItem.longName)	
		$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
		$discoveryData.AddInstance($srcInstance)

		$tableSpaceInstances = $dboTableSpace | Where-Object {$_.dbName -imatch $dbName}

		foreach($tablespace in $tableSpaceInstances) {
			$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']$")
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$", $dbName)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/uniqueId$", $tablespace.uniqueId)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$", $tablespace.longName)		
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/tableSpaceName$", $tablespace.tableSpaceName)		
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/status$", $tablespace.status)		
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/contents$", $tablespace.contents)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/retention$", $tablespace.retention)
			$targetInstance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/blocksize$", $tablespace.blocksize)		
			$discoveryData.AddInstance($targetInstance)
	
			$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Connect.APM.Foglight.DatabaseHostsTablespace']$")
			$relInstance.Source = $srcInstance
			$relInstance.Target = $targetInstance
			$discoveryData.AddInstance($relInstance)

			$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
			$relHealthInstance.Source = $healthInstance
			$relHealthInstance.Target = $targetInstance									
			$discoveryData.AddInstance($relHealthInstance)

		} #end foreach($tablespace in $tableSpaceInstances)				

	} #end foreach  ($dboDBItem in $dboDatabase) 
		
} else {

	$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBORelations.ps1',111,1,"DiscoverDBORelations.ps1 - APM Server $($apmServerURL) is NOT reachable with PING. Stopping further processing!")
	Exit

}

$discoveryData