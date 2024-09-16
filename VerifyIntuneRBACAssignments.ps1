#Requires -Modules Microsoft.Graph.Authenticaion,Microsoft.Graph.Beta.DeviceManagement.Administration,Microsoft.Graph.Groups

$graphURL = "https://graph.microsoft.com/beta/deviceManagement"

$RBACReportDetailed = [System.Collections.Generic.List[PSCustomObject]]::new() 
#Getting all Intune Roles 
Try {
    $AllIntuneRoles = Get-MgBetaDeviceManagementRoleDefinition -All -Property Id, DisplayName, IsBuiltIn
} Catch {
    Throw "Couldn't obtain all Roles Error: $_"
}
#Looping through all Intune Roles 
foreach ($IntuneRole in $AllIntuneRoles) {

    $Uri = $graphURL + "/roleDefinitions/$($IntuneRole.Id)/roleAssignments"
    $RoleAssignments = (Invoke-MgGraphRequest -Method GET -Uri $Uri).Value

    if ( $($RoleAssignments.Count) -gt 0 ) {
        Write-Output "The Role $($IntuneRole.DisplayName) has $($RoleAssignments.Count) assignments"

        #Processing all role assignments on the role
        foreach ($RoleAssignment in $RoleAssignments) {

            Write-Output "Processing Assignment $($RoleAssignment.displayName)..."

            $Uri = $graphURL + "/roleDefinitions/$($IntuneRole.Id)/roleAssignments/$($RoleAssignment.Id)"
            $AssignedGroups = (Invoke-MgGraphRequest -Method GET -Uri $Uri)

            If ($AssignedGroups.Count -gt 0) {
                Write-Output "The Assignment $($RoleAssignment.displayName) has $($AssignedGroups.Count) Member Groups."

                foreach ($AssignedGroup in $AssignedGroups) {

                    #Looping through all Member groups (Member groups eq admin groups which are part of the role assignment)
                    foreach ($Membergroup in $AssignedGroups.members) {

                        $GroupMembers = Get-MgGroupMember -GroupId $($Membergroup)

                        $GroupDetails = Get-MgGroup -GroupId $($Membergroup) -Property DisplayName, Id, IsAssignableToRole

                        If ($GroupMembers.Count -gt 0) {

                            foreach ($GroupMember in $GroupMembers) {
                                $userinfo = [ordered]@{
                                    IntuneRole                = $IntuneRole.DisplayName
                                    BuiltInRole               = $IntuneRole.IsBuiltIn
                                    RoleAssignment            = $RoleAssignment.displayName
                                    RoleGroup                 = $GroupDetails.DisplayName
                                    RoleGroupisRoleAssignable = $GroupDetails.IsAssignableToRole
                                    AdminUser                 = $GroupMember.AdditionalProperties.userPrincipalName
                                }
                                $RBACReportDetailed.Add([PSCustomObject]$userinfo)
                            }
                        } 
                    }                
                }
    
            }
        } 
    }
}

$RBACReportDetailed | Export-Csv -NoTypeInformation C:\Temp\rbacexport.csv -Force
