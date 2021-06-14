using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Attempting to import the needed Modules
import-module .\Modules\New-GraphAPIToken\New-GraphAPIToken.psm1

# Checking if the needed ENVs exist
. .\Shared\Check-ENVs.ps1

# Gathering a token and setting the headers
$GraphAPIToken = New-GraphAPIToken -ClientID $env:ClientID -ClientSecret $env:ClientSecret -TenantID $env:TenantID
$Headers = $GraphAPIToken.Headers

# Importing Functions
Write-output "Importing functions"
Import-Module .\Modules\GraphGroupFunctions\GraphGroupFunctions.psm1

# Determine if this is a get or a post, and gather the request to process.
switch ($Request.Method) {
    'Get' {
        $RequestToProcess = $Request.Query
        if (-not $RequestToProcess.TeamName) {
            Write-Output "Sending bad request response"
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body = $("Request not formatted properly")
            })
            break
        }
        Write-output "Gathering team info"

        # Getting the name of the group to find
        $TeamName = $RequestToProcess.TeamName

        # Getting the template
        $GuestTemplate = Get-GraphGroupGuestTemplate -Headers $Headers

        # Getting the graph group
        $Group = Get-GraphGroup -Headers $Headers -TeamName $TeamName

        # Getting the graph group settings
        $Settings = Get-GraphGroupGuestSettings -Headers $Headers -GroupID $group.id

        $body = [PSCustomObject]@{
            DisplayName = $group.displayName
            ID = $group.ID
            AllowToAddGuests = $Settings.values.value
        }

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Write-Output "Sending response"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $($body|ConvertTo-Json)
        })
    }
    'Post' {
        $RequestToProcess = $Request.Body
        if (-not $RequestToProcess.TeamName) {
            Write-Output "Sending bad request response"
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body = $("Request not formatted properly")
            })
            break
        }
        Write-Output "Request: $($RequestToProcess|ConvertTo-Json)"
        Write-Output "Processing request for ticket $($RequestToProcess.TicketID)"
        Write-output "Gathering team info"
        # Getting the name of the group to find
        $TeamName = $RequestToProcess.TeamName

        # Getting the template
        $GuestTemplate = Get-GraphGroupGuestTemplate -Headers $Headers

        # Getting the graph group
        $Group = Get-GraphGroup -Headers $Headers -TeamName $TeamName

        # Setting the graph group settings
        Write-output "Setting team info"
        $Settings = Set-GraphGroupGuestSettings -Headers $Headers -GroupUnifiedGuestTemplateID $GuestTemplate.id -GroupID $Group.id -AllowToAddGuests $RequestToProcess.GuestSettingsEnabled

        $body = [PSCustomObject]@{
            DisplayName = $group.displayName
            ID = $group.ID
            AllowToAddGuests = $Settings.values.value
        }

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Write-Output "Sending response"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $($body|ConvertTo-Json)
        })
    }
    Default {
        Write-Error "Could not determine request type."
    }
}
