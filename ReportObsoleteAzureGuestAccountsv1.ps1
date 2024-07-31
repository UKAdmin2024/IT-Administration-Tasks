# Author Daniel Bhatoa, 2024
# This script is used to find all obsolete guest accounts in Azure that should be deleted
# This script script currently returns all unlicensed guest users in Azure, then filters out ones which haven't logged in the last year and haven't been created recently
Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All" -nowelcome

$date=get-date -Format "HH-mm-dd-MM-yy"
$logfile="c:\temp\StaleEntraIDGuests_log-" + $date + ".csv"

$staleUsercount=0
$unlicensedguests=0
[int]$guestaccountstobedeleted=0
# Get the current date
$currentDate = Get-Date
# Calculate the threshold date and createdwitindate
[datetime]$thresholdDate = $currentDate.AddDays(-365)
[datetime]$notcreatedwithin = $currentDate.AddDays(-60)
#array object to add users
$results = @()

# Get a list of users who haven't signed in since the threshold date
 
$Unlicensedguests = Get-MgUser -All -filter "assignedLicenses/`$count eq 0 and usertype eq 'guest'" -consistencyLevel eventual -CountVariable records

foreach ($user in $unlicensedguests){

            $guest=get-mguser -userid (get-mguser -UserId $user.userprincipalname).id -Property createdDatetime,signinactivity,userprincipalname
             write-host "processing guest " $guest.userprincipalname
     
      # Build a results object for each user
      $results_obj = New-Object -TypeName psobject -Property @{
        upn = $guest.UserPrincipalName
        CreatedDate = $guest.CreatedDateTime
        LastSignInDate=$guest.SignInActivity.LastSignInDateTime
                                                               } 
        $results += $results_obj
      
      
      # This block so far just exports key information to CSV
      #} This bracket needs to go to make below main block work
        
      
      # CHECK FOR NULL DATE TYPES as null conversion will throw an error

      if ($guest.SignInActivity.LastSignInDateTime -eq $null) 
            {    
            write-host $guest.UserPrincipalName " HAS NEVER SIGNED IN"
            #now check if it's been recently created

                  if  ([datetime]$guest.CreatedDateTime -lt $notcreatedwithin ) 
      
                  {
                    #user has never signed in and has not recently been created, candidate for deletion, write to log file
                    Write-Host -f Yellow $guest.UserPrincipalName " HAS NEVER SIGNED IN (NULL VALUE) AND HAS NOT BEEN CREATED RECENTLY - SHOULD BE DELETED"
                    $guest.UserPrincipalName + ";" +  $guest.signinactivity.LastSignInDateTime + ";" + $guest.CreatedDateTime + ";" + " has never signed in and should be deleted " | Out-File $logfile -Append  
                  # incrememnt deletion counter
                  $guestaccountstobedeleted++
                  }
      
      
                }
      
       elseif (([datetime]$guest.SignInActivity.LastSignInDateTime -lt $thresholdDate)   -and ([datetime]$guest.CreatedDateTime -lt $notcreatedwithin ))
      {
      #user hasn't logged in for a long time and has not recently been created, candidate for deletion, write to log file
        Write-Host -f Red $guest.UserPrincipalName " hasn't signed in over a year and hasn't been created within the last two months, this is a candidate for deletion" 
        $guest.UserPrincipalName + ";" +  $guest.signinactivity.LastSignInDateTime + ";" + $guest.CreatedDateTime + ";" + " hasn't signed in for over a year and should be deleted " | Out-File $logfile -Append  
        $guestaccountstobedeleted++
      }

          
      }

 write-host " This many guest accounts should be deleted "$guestaccountstobedeleted
 $results | export-csv C:\Temp\EntraIDGuestAccountsToBeDeleted.csv -NoTypeInformation -Delimiter ";"
 $guestaccountstobedeleted.ToString() + " guest accounts have been processed and should be deleted" | Out-File $logfile -Append
