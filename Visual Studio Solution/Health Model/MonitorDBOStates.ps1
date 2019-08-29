param($QryItem)

$api = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$script:ErrorView      = 'NormalView'
$ErrorActionPreference = 'Continue'

$testedAt = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"

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

$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',130,4,"MonitorDBOStats.ps1 - Starting with APM Server query $($apmServerURL)")

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
		'aggregateAlarms'
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
		'aggregateAlarms'
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
		'aggregateAlarms'
	)

	switch ($qryItem) {
		"Servers"  {			
			
			$body = @{ "queryText" = "!DBO_Servers"	} | ConvertTo-Json
			$dboServersRaw = ''
			$dboServersRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboServersRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - DiscoverDBOs.ps1',131,4,"Query $($qryItem), returned $($dboServersRaw.data.count) objects.")
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
							  'aggregateAlarms'          = $tmp.aggregateAlarms.message
							  'activeHost'               = $activeHost
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				}
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboServersRaw.data.count) objects! Check query.")
			}
			break
		} #end Servers   
		"Database"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboDatabaseRaw = ''
			$dboDatabaseRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboDatabaseRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,4,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects.")
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
							  'aggregateAlarms'          = $tmp.aggregateAlarms.message
						}
						if ($dbName -ne '' -and $dbname -match '[a-zA-Z]{1,}') {
							$null = $tmpList.Add($dboObj)
						}												
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboDatabaseRaw.data.count) objects! Check query.")
			}
			break
		} #end Database
		"Listener"  {			
			
			$body = @{ "queryText" = "!DBO_Listener_Status" } | ConvertTo-Json
			$dboListenerStatusRaw = ''
			$dboListenerStatusRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboListenerStatusRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,4,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects.")
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
							'aggregateAlarms'          = $tmp.aggregateAlarms.message
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboListenerStatusRaw.data.count) objects! Check query.")
			}
			break
		} #end Listener
		"DB-System"  {			
			
			$body = @{ "queryText" = "!DBO_Database" } | ConvertTo-Json
			$dboSystemRaw = ''
			$dboSystemRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json
			
			if ($dboSystemRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,4,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects.")
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
							  [string]'uniqueId'         = $uniID  = $uniID + '-Sys'
							  [string]'longName'         = $tmp.longName + '_Long'
							  [string]'dbName'           = $dbName							  
						}
						if ($dbName -ne '' -and $dbname -match '[a-zA-Z]{1,}') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboSystemRaw.data.count) objects! Check query.")
			}
			break
		} #end DB-System
		"Tablespace"  {			
			
			$body = @{ "queryText" = "!DBO_Tablespace" } | ConvertTo-Json
			$dboTableSpaceRaw = ''
			$dboTableSpaceRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboTableSpaceRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,4,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects.")
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
							'aggregateAlarms'          = $tmp.aggregateAlarms.message
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				}

			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboTableSpaceRaw.data.count) objects! Check query.")
			}
			break
		} #end Tablespace
		"Agent"  {			
			
			$body = @{ "queryText" = "!DBO_Agent_Model" } | ConvertTo-Json
			$dboAgentModelRaw = ''
			$dboAgentModelRaw = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType application/json

			if ($dboAgentModelRaw.data.count -ge 1) {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,4,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects.")
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
							'aggregateAlarms'          = $tmp.aggregateAlarms.message
						}
						if ($dbName -ne '') {
							$null = $tmpList.Add($dboObj)
						}						
					}
				} 
			} else {
				$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',131,1,"Query $($qryItem), returned $($dboAgentModelRaw.data.count) objects! Check query.")
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

	$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',132,4,"MonitorDBOStats.ps1 - APM Server $($apmServerName) is reachable via PING.")
	$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',133,2,"MonitorDBOStats.ps1 - QueryItem ($qryItem) ")

	$dboList = New-Object -TypeName System.Collections.ArrayList
	Get-DBOFromFoglightWebService -qryItem $qryItem -apmServerURL $apmServerURL -apmServerAuthToken $apmServerAuthToken -outList ([ref]$dboList)

	$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',134,1,"MonitorDBOStats.ps1 - dboList $($dboList.Count) ")

	foreach ($dboItem in $dboList) {
		$state = 'Green'
		switch ($dboItem.aggregateState) {
			'0' { 
				$state = 'Green'
				break
			}
			'1' { 
				$state = 'Yellow'
				break
			}
			'2' { 
				$state = 'Yellow'
				break
			}
			'3' { 
				$state = 'Red'
				break
			}
			'4' { 
				$state = 'Red'
				break
			}
		}

		$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',135,2,"Sending LongName $($dboItem.longName); UniqueId $($dboItem.uniqueId); State $($state); testedAt $($testedAt); alarmtext $($dboItem.aggregateAlarms)   ")

		$bag = $api.CreatePropertybag()					
		$bag.AddValue("Name",$dboItem.longName)
		$bag.AddValue("uniqueId",$dboItem.uniqueId)		
		$bag.AddValue("State",$state)				
		$bag.AddValue("AlarmText",$dboItem.aggregateAlarms)		
		$bag.AddValue("TestedAt",$testedAt)			
		$bag

	}	
	
} else {

	$api.LogScriptEvent('Connect.APM.Foglight - MonitorDBOStats.ps1',132,1,"MonitorDBOStats.ps1 - APM Server $($apmServerName) is NOT reachable with PING. Stopping further processing!")

}
