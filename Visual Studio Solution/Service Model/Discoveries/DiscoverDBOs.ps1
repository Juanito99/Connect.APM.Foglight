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

$apmRegPath               = 'HKLM:\SOFTWARE\ABCIT\APMFoglight'
$apmServerAuthToken       = Get-ItemProperty -Path $apmRegPath | Select-Object -ExpandProperty APMServerAuthToken
$apmServerURL             = Get-ItemProperty -Path $apmRegPath | Select-Object -ExpandProperty APMServerURL

$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',100,4,"DiscoverDBOs.ps1 - Starting with APM Server query $($apmServerURL)")

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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboServersRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboServersRaw.data.count) objects! Check query.")
			}
			break
		} #end Servers   
		"Database"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboDatabaseRaw = ''
			$dboDatabaseRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboDatabaseRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects! Check query.")
			}
			break
		} #end Database
		"Listener"  {			
			
			$body = @{ "queryText" = "!DBO_Listener_Status" } | ConvertTo-Json
			$dboListenerStatusRaw = ''
			$dboListenerStatusRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboListenerStatusRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects! Check query.")
			}
			break
		} #end Listener
		"DB-System"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboSystemRaw = ''
			$dboSystemRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json
			
			if ($dboSystemRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects! Check query.")
			}
			break
		} #end DB-System
		"Tablespace"  {			
			
			$body = @{ "queryText" = "!DBO_Tablespace" } | ConvertTo-Json
			$dboTableSpaceRaw = ''
			$dboTableSpaceRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboTableSpaceRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects! Check query.")
			}
			break
		} #end Tablespace
		"Agent"  {			
			
			$body = @{ "queryText" = "!DBO_Agent_Model" } | ConvertTo-Json
			$dboAgentModelRaw = ''
			$dboAgentModelRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboAgentModelRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects.")
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
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects! Check query.")
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


Function Publish-ObjectsToSCOM {

	param(
		[string]$qryItem,
		[System.Collections.ArrayList]$dboList
	)

	$rtn = $false

	$fglClasses = @{
		'Servers'    = 'Connect.APM.Foglight.DBO.Server'
		'Database'   = 'Connect.APM.Foglight.DBO.Database'
		'DB-System'  = 'Connect.APM.Foglight.DBO.DatabaseSystem'
		'Tablespace' = 'Connect.APM.Foglight.DBO.Tablespace'
		'Agent'      = 'Connect.APM.Foglight.DBO.Agent'
		'Listener'   = 'Connect.APM.Foglight.DBO.Listener'
	}

	$fglClass = $fglClasses[$qryItem]

	foreach ($dboItm in $dboList) {

		$displayName = "$($qryItem)-$($dboItm.dbName)" + '-(Foglight)'

		if($qryItem -eq 'Servers') {
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Server']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Server']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Server']/activeHost$",$dboItm.activeHost)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} elseif ($qryItem -eq 'Database') {
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Database']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Database']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} elseif ($qryItem -eq 'DB-System') {
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.DatabaseSystem']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.DatabaseSystem']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} elseif ($qryItem -eq 'Listener') {
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Listener']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Listener']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} elseif ($qryItem -eq 'Tablespace') {
			$displayName = "$($qryItem)-$($dboItm.dbName)-$($dboItm.tableSpaceName)"
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/tableSpaceName$",$dboItm.tableSpaceName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/status$",$dboItm.status)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/contents$",$dboItm.contents)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/retention$",$dboItm.retention)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Tablespace']/blocksize$",$dboItm.blocksize)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} elseif ($qryItem -eq 'Agent') {
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']$")
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/uniqueId$",$dboItm.uniqueId)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/longName$",$dboItm.longName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Base']/dbName$",$dboItm.dbName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/agentVersion$",$dboItm.agentVersion)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/agentName$",$dboItm.agentName)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/build$",$dboItm.build)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/monitoringHost$",$dboItm.monitoringHost)
			$instance.AddProperty("$MPElement[Name='Connect.APM.Foglight.DBO.Agent']/type$",$dboItm.type)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)
		} else {
			$foo = 'bar'
		}
	} #end foreach ($dboItm in $dboList)

	if($Error) {
		$rtn = $false
		$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',103,1,"DiscoverDBOs.ps1 - Error occured during Publish function $($Error)")
	} else {
		$rtn = $true
		$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',103,4,"DiscoverDBOs.ps1 - No Error occured during Publish function.")
	}

	$rtn
		
} #end Function Publish-ObjectsToSCOM

	

$apmServerName = $apmServerURL  -replace ':[\d]{1,}',''
$apmServerName = $apmServerName -replace '(?i)https?://',''

if (Test-Connection -ComputerName $apmServerName -Count 2 -Quiet) {

	$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,4,"DiscoverDBOs.ps1 - APM Server $($apmServerURL) is reachable via PING.")

	$itemList = @('Servers','Database','DB-System','Tablespace','Agent','Listener')

	foreach ($qryItem in $itemList) {

		$dboList = New-Object -TypeName System.Collections.ArrayList
		Get-DBOFromFoglightWebService -qryItem $qryItem -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken  -outList ([ref]$dboList)

		Publish-ObjectsToSCOM -qryItem $qryItem -dboList $dboList

	} 
	
} else {

	$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',101,1,"DiscoverDBOs.ps1 - APM Server $($apmServerURL) is NOT reachable with PING. Stopping further processing!")

}

$discoveryData