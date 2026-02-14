connect-azaccount -identity

$subs = Get-AzSubscription  

$changelist = ''

   foreach ($sub in $subs) 
   {
        Set-AzContext -Subscription $($sub.name)  
        $subscriptioname = $($sub.name)  
        $subscriptionid = $($sub.id)
         


$storageaccountlist  = get-azstorageaccount 


    foreach($storageaccounttochange in $storageaccountlist)
    {

        $storageobj = new-object PSObject 

         $storageobj | add-member  -MemberType NoteProperty -Name StorageAccountName -Value $($storageaccounttochange.StorageAccountName)
         $storageobj | add-member  -MemberType NoteProperty -Name ResourceGroupName -Value $($storageaccounttochange.ResourceGroupName)
         $storageobj | add-member  -MemberType NoteProperty -Name subscriptionname -Value $($sub.name)
         $storageobj | add-member  -MemberType NoteProperty -Name subscriptionid -Value  $($sub.id)
         [array]$changelist += $storageobj

    } 
}

$changelist  | where subscriptionname  -ne ''  | select subscriptionname, subscriptionid, Storageaccountname, Resourcegroupname | export-csv c:\temp\nopublicaccess_storage.csv -NoTypeInformation



