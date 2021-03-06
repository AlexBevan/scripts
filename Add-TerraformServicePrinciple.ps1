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
        start-sleep 10
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

        $json = @'
[
    {
        "resourceAppId": "00000002-0000-0000-c000-000000000000",
        "resourceAccess": [
            {
                "id": "970d6fa6-214a-4a9b-8513-08fad511e2fd",
                "type": "Scope"
            },
            {
                "id": "1cda74f2-2616-4834-b122-5cb1b07f8a59",
                "type": "Role"
            },
            {
                "id": "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7",
                "type": "Role"
            },
            {
                "id": "78c8a3c8-a07e-4b9e-af1b-b5ccab50a175",
                "type": "Role"
            }
        ]
    }
]
'@
        out-file test.json
        Add-Content -Path testjson.json -Value $json
        write-host "Add SP to GraphAPI"
        $api = (az ad app update --id $sp.appId --required-resource-accesses testjson.json)
        remove-item ./testjson.json -force  
        write-host "Consent GraphAPI access"
        az ad app permission admin-consent --id $sp.appId
        start-sleep 10

        $apiUrl = 'https://graph.microsoft.com/v1.0/directoryRoles/'
        $Data = Invoke-RestMethod -Headers @{Authorization = "Bearer $($token)"} -Uri $apiUrl -Method Get
        $RoleID = (($Data | Select-Object Value).Value | Where-Object {$_.displayName -eq "User Account Administrator"} | Select-Object id).id

        $payload = (@{“@odata.id” = “https://graph.microsoft.com/v1.0/directoryObjects/$sp_ob_id”} | ConvertTo-Json )
        $apiUrl = "https://graph.microsoft.com/v1.0/directoryRoles/$RoleID/members/\`$ref"
        $payload = $payload -replace "`"", "\`""
        write-host "Add user to User Account Administrator role"
        az rest --method post --uri $apiUrl --body $payload
    }
    END
    {
        return $ourObject
    }   
    }
