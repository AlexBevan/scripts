<#
.SYNOPSIS
    Creates a service principle and graph api access required for the azurerm and azuread terraform provider
.DESCRIPTION
    Creates a service principle and graph api access required for the azurerm and azuread terraform provider, run az-login as a user with domain admin.
.PARAMETER name
    The name you wish to give your service principle
.EXAMPLE
    az-login
    $CraigTerraform = Add-TerraformServicePrinciple -name CraigDavid-TF
    write-host $CraigTerraform.Client_ID
.NOTES
    Author: Alex Bevan
    Date:   July 7, 2020    
#>
function Add-TerraformServicePrinciple {
    param(
        [string] $name = "terraform-" + (get-random)
        )
    BEGIN
    {
        $ourObject = New-Object -TypeName psobject 
        $sp = az ad sp create-for-rbac --skip-assignment --name $name | ConvertFrom-Json
        $sp_ob_id = (az ad sp show --id $sp.appId | convertfrom-json).objectId
    }
    
    PROCESS
    {
        $ourObject | Add-Member -MemberType NoteProperty -Name CLIENT_ID -Value $sp.appId
        $ourObject | Add-Member -MemberType NoteProperty -Name CLIENT_SECRET -Value $sp.password
        $ourObject | Add-Member -MemberType NoteProperty -Name TENANT_ID -Value $sp.tenant
        $ourObject | Add-Member -MemberType NoteProperty -Name CLIENT_OBJECT_ID -Value $sp_ob_id

        $token = (az account get-access-token --resource=https://graph.microsoft.com | convertfrom-json).accessToken

        $resourceID = (az ad sp show --id 00000003-0000-0000-c000-000000000000 | convertfrom-json).objectId
        
        $body = @{
            clientId    = $sp_ob_id
            consentType = "AllPrincipals"
            principalId = $null
            resourceId  = $resourceID
            scope       = "User.Read User.Read.All User.ReadBasic.All User.ReadWrite User.ReadWrite.All Group.Read.All Group.ReadWrite.All Domain.Read.All Directory.Read.All GroupMember.Read.All GroupMember.ReadWrite.All"
            startTime   = "2019-10-19T10:37:00Z"
            expiryTime  = "2019-10-19T10:37:00Z"
        }
        $apiUrl = "https://graph.microsoft.com/beta/oauth2PermissionGrants"
        Try {
            $r = Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($token)" }  -Method POST -Body $($body | convertto-json) -ContentType "application/json" | out-null
           }
           catch {Failure}
    }
    END
    {
        return $ourObject
    }
        
        
        
    }


