<#
.SYNOPSIS
	Check Azure AD Connect Sync Health.
.DESCRIPTION
	The get-azureadconnectsync.ps1 uses Custom Sensor "EXE/Script" to check Azure AD Connect Sync status and returns PRTG output and code.
	Security must be set to "Use Windows credentials of parent device"
.PARAMETER WinUser
	Windows Credentials
.PARAMETER WinPass
	Windows Password for Credentials
.PARAMETER WinHost
	Remotehost
.PARAMETER Hours
	Hours since the last password synchronization.
	Default: 3
.EXAMPLE
	get-azureadconnectsync.ps1 -WinUser '%windowsdomain\%windowsuser' -WinPass '%windowspassword' -WinHost '%host'
	(Variables are PRTG Placeholder and must be presented as Sensor Settings - Parameters of Sensor "EXE/Script")
.OUTPUTS
	Azure AD Connect Sync is up and running. Latest heart beat event (within last -Hours). Time .
	Azure AD Connect Sync sync cycle enabled and not synced within last -Hours.
	Azure AD Connect Sync sync cycle not enabled.
.NOTES 
	Author:		Patrick Acker
	Version: 	1.1
	Version History:
		1.1  03.12.2019  Complete Rebuilt for PRTG Network Monitor (thanks to Marvin S.)
		1.0  15.02.2018  Original GitHub release by Juan Granados (https://github.com/juangranados/nagios-plugins )
#>

Param(	
	[string]$WinUser,
   	[string]$WinPass,
	[string]$WinHost,
	[Parameter(Mandatory=$false,Position=0)]
	[ValidateNotNullOrEmpty()]
	[int]$Hours=3
)

$Output = ""
$ExitCode = 0
#Create credential object
$WinCred = New-Object System.Management.Automation.PSCredential -ArgumentList $WinUser, ($WinPass | ConvertTo-SecureString -AsPlainText -Force)

#Using Get-WinEvent to use Cred
$pingEvents = Get-WinEvent -ComputerName $WinHost -Credential $WinCred -Filterhashtable @{LogName="Application"; ID=654; StartTime=(Get-Date).AddHours(-$($Hours))} -ErrorAction SilentlyContinue | Sort-Object { $_.TimeCreated } -Descending
if ($pingEvents -ne $null) {
	$Output = "Latest heart beat event (within last $($Hours) hours). Time $($pingEvents[0].TimeCreated)."
}
else{
	$Output = "No ping event found within last $($Hours) hours."
	$ExitCode = 1
}

$arrService = Invoke-Command -ComputerName $WinHost -Credential $WinCred -ScriptBlock {Get-Service -Name ADSync}
 if ($arrService.Status -ne "Running"){
 $ExitCode = 2
 }

# Up State
If ($ExitCode -eq 0){
	Write-Host $ExitCode,":Azure AD Connect Sync is up and running. $($Output)"
	Exit 0
}
# Warning State
ElseIf($ExitCode -eq 1){
	Write-Host $ExitCode,":Azure AD Connect Sync is enabled, but not syncing. $($Output)"
	Exit 1
}
# Down State
ElseIf($ExitCode -eq 2){
	Write-Host $ExitCode,":Azure AD Connect Sync is disabled. $($Output)"
	Exit 2
}

$Host.SetShouldExit($ExitCode)