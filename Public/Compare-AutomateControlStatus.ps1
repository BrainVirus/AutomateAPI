function Compare-AutomateControlStatus {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $ComputerObject,
        
        [Parameter()]
        [switch]$AllResults,

        [Parameter()]
        [switch]$Quiet
    )
    
    begin {
        $ComputerArray = @()
        $ObjectRebuild = @()
        $ReturnedObject = @()
    }
    
    process {
        if ($ComputerObject) {
            $ObjectRebuild += $ComputerObject 
        }

    }
    
    end {
        # The primary concern now is to get out the ComputerIDs of the machines of the objects
        # We want to support all ComputerIDs being called if no computer object is passed in
        If(!$Quiet){Write-Host -BackgroundColor Blue -ForegroundColor White "Checking to see if the recommended Internal Monitor is present"}
        $AutoControlSessions=@{};
        $InternalMonitorMethod = $false
        $Null=Get-AutomateAPIGeneric -Endpoint "InternalMonitorResults" -allresults -condition "(Name like '%GetControlSessionIDs%')" -EA 0 | Where-Object {($_.computerid -and $_.computerid -gt 0 -and $_.IdentityField -and $_.IdentityField -match '.+')} | ForEach-Object {$AutoControlSessions.Add($_.computerid,$_.IdentityField)};

        # Check to see if the Internal Monitor method has results
        if ($AutoControlSessions.Count -gt 0){$InternalMonitorMethod = $true; If(!$Quiet){Write-Host -BackgroundColor Green -ForegroundColor Black "Internal monitor found. Processing results."} } Else {If(!$Quiet){Write-Host -ForegroundColor Black -BackgroundColor Yellow "Internal monitor not found. This cmdlet is significantly faster with it. See https://www.github.com/gavsto/automateapi"}}

        # Check to see if any Computers were specified in the incoming object
        if(!$ObjectRebuild.Count -gt 0){$FullLookupMethod = $true}

        if ($FullLookupMethod) {
            $ObjectRebuild = Get-AutomateComputer -AllComputers | Select-Object Id, ComputerName, @{Name = 'ClientName'; Expression = {$_.Client.Name}}, OperatingSystemName, Status 
        }

        foreach ($computer in $ObjectRebuild) {
            If(!$InternalMonitorMethod)
            {
                $AutomateControlGUID = Get-AutomateControlInfo -ComputerID $($computer | Select-Object -ExpandProperty id) | Select-Object -ExpandProperty SessionID
            }
            else {
                $AutomateControlGUID = $AutoControlSessions[[int]$Computer.ID]
            }

            $FinalComputerObject = ""
            $FinalComputerObject = [pscustomobject] @{
                ComputerID = $Computer.ID
                ComputerName = $Computer.ComputerName
                ClientName = $Computer.Client.Name
                OperatingSystemName = $Computer.OperatingSystemName
                OnlineStatusAutomate = $Computer.Status
                OnlineStatusControl = ''
                SessionID = $AutomateControlGUID
            }

            $ComputerArray += $FinalComputerObject
        }

        #GUIDs to get Control information for
        #$GUIDsToLookupInControl = $ComputerArray | Select-Object -ExpandProperty SessionID

        #Control Sessions
        $ControlSessions = Get-ControlSessions

        foreach ($final in $ComputerArray) {
            
            if (![string]::IsNullOrEmpty($Final.SessionID)) {
                if ($ControlSessions.Containskey($Final.SessionID)) {
                    $ResultControlSessionStatus = $ControlSessions[$Final.SessionID]
                }
                else
                {
                    $ResultControlSessionStatus = "GUID Not in Control or No Connection Events"
                } 
            }
            else
            {
                $ResultControlSessionStatus = "Control not installed or GUID not in Automate"
            }

        
            $CAReturn = ""
            $CAReturn = [pscustomobject] @{
                ComputerID = $final.ComputerID
                ComputerName = $final.ComputerName
                ClientName = $final.ClientName
                OperatingSystemName = $final.OperatingSystemName
                OnlineStatusAutomate = $final.OnlineStatusAutomate
                OnlineStatusControl = $ResultControlSessionStatus
                SessionID = $final.SessionID
            }

            $ReturnedObject += $CAReturn
        }
        
        if ($AllResults) {
            $ReturnedObject
        }
        else
        {
            $ReturnedObject | Where-Object{($_.OnlineStatusControl -eq $true) -and ($_.OnlineStatusAutomate -eq 'Offline') }
        }
        

    }
}