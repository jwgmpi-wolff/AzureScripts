install-Module Microsoft.Graph  -allowclobber 
#install-module Microsoft.Graph.Reports -allowclobber 
import-module azureAD -force
Import-Module Microsoft.Graph.Reports
Import-Module Microsoft.Graph.Users.Functions
import-module az.automation -force -Verbose

Disconnect-MgGraph

#connect-azaccount -tenantid e594a530-1ec9-4192-a8d4-a9111f8cffa7 -ApplicationId  81f8949a-7a41-4020-942c-c561aeeba7a7  

 connect-azaccount -Identity 

  connect-mggraph   -Identity  

 connect-azuread      -ApplicationId 81f8949a-7a41-4020-942c-c561aeeba7a7 -TenantId e594a530-1ec9-4192-a8d4-a9111f8cffa7 -CertificateThumbprint c8ffeac7-d670-43c5-8161-fd279f6447a6

 $sp =  Get-AzADServicePrincipal -ApplicationId 81f8949a-7a41-4020-942c-c561aeeba7a7

$tenant = get-aztenant -TenantId e594a530-1ec9-4192-a8d4-a9111f8cffa7
 


Get-MgAuditLogProvisioning -All 



     Get-MgDevice -DeviceId $($userauth.id)


 



