$serviceId = $vmService.Id
$date = get-date -Format "ddMMyyyy"
$TICKETNAME = "$($subscriptionselected.name)_$($VMFAMILY)_$DATE"
$TICKETNAME
get-AzSupportTicket -Name "$TICKETNAME"










