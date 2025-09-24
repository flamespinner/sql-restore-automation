$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:4000/')  # Use HTTP unless you have a certificate for HTTPS
$listener.Start()
$username = 'sqluser'
$password = 'sqlpassword'
$azconnectionstring = 'azconnectionstring'
$clientid = "client id from app registration"
$tenantid = "azure tenant id"
$thumbprint = "thumbprint from azure"
$containerName = 'blob storage contaner'
$databasename = 'db name'
$pathToPermissionsCsv = "some path here"
$dbofflinecommand = "ALTER DATABASE <DATABASEHERE> SET OFFLINE WITH ROLLBACK IMMEDIATE;"
$sizequery = "sp_helpdb '<DATABASENAME>'"

Write-Host "✅ Listening for incoming events on http://+:4000/"

$expectedSecret = "expectedSecret"  # Shared secret

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $actualSecret = $request.Headers["X-Webhook-Secret"]
    
    # Optional: read request body if needed
    $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    # Log the request (for debugging)
    Write-Host "--------------------------------------------"
    Write-Host "🔐 Secret header received: $actualSecret"
    Write-Host "📦 Payload:"
    Write-Host $body

    # Secret validation
    if ($actualSecret -ne $expectedSecret) {
        Write-Host "❌ Unauthorized: Invalid secret"
        $response.StatusCode = 401
        $response.StatusDescription = "Unauthorized"
        $response.Close()
        continue
    }

    $response.StatusCode = 200
    $response.StatusDescription = "Accepted"
    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("Accepted"))
    $response.OutputStream.Close()

    # Extract filename from JSON payload
    try {
        $json = $body | ConvertFrom-Json
        $blobUrl = $json.blobUrl
        $filename = [System.IO.Path]::GetFileName($blobUrl)
        Write-Host "📄 Extracted filename: $filename"

        $response.StatusCode = 200
        $response.StatusDescription = "OK"
        
        try {

            Import-Module -Name Az -WarningAction SilentlyContinue
            Import-Module -Name SqlServer -WarningAction SilentlyContinue
            $DestinationFolder = "D:\"
            $AZContext = New-AzStorageContext -ConnectionString $azconnectionstring

            #GRAPH API CREDENTIALS
            $userId = "user UPN"
            #END OF GRAPH API CREDENTIALS

            $StopWatch = new-object system.diagnostics.stopwatch

            $StopWatch.Start()

            Get-AzStorageBlobContent -Container $containerName -Blob $filename -Context $AZContext -Destination $DestinationFolder -Force
            Invoke-Sqlcmd -ServerInstance "localhost" -U $username -P $password -TrustServerCertificate -Query $dbofflinecommand
                
            Restore-SqlDatabase -ServerInstance "localhost" -Database $databasename -BackupFile $filename -AutoRelocateFile -ReplaceDatabase -Verbose

            Invoke-Sqlcmd -ServerInstance "localhost" -U $username -p $password -TrustServerCertificate -InputFile $pathToPermissionsCsv

            Write-Host Restore Complete. 

            $StopWatch.Stop()

############################################### ALERT EMAIL ################################################
            Write-Host "Sending Alert Email"

            Connect-MgGraph -ClientID $clientid -TenantId $tenantid -CertificateThumbprint $thumbprint -NoWelcome
            $Minutes = $StopWatch.Elapsed.TotalMinutes
            $getdbsize = Invoke-Sqlcmd -ServerInstance localhost -U $username -P $password -TrustServerCertificate -Query $sizequery
            $dbsize = $getdbsize.db_size[0] -replace '[^0-9.]', ''  # Extract numeric value
            $dbsizeGB = [double]$dbsize / 1024
            Write-Output "Database Size in GB: $dbsizeGB"
            
            #MAIL ALERT PARAMETERS

            $params = @{
                message = @{
                    subject = "Email Subject goes here"
                    body = @{
                        contentType = "Text"
                        content = "Message Body Goes here
                        Debug:
                        $Minutes minutes
                        Database Size MB: $dbsize
                        Database Size GB: $dbsizeGB
                        Import File: $filename"
                    }
                    toRecipients = @(
                        @{
                            emailAddress = @{
                                address = 'test@test.com'
                            }
                        }
                    )
                }
                saveToSentItems = "true"
            }

            Send-MgUserMail -UserId $userId -BodyParameter $params

        } catch {
            Write-Error "Error Processing event $eventId $_"
            $response.StatusCode = 500
        } finally {
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            Write-Host "We're done here"
        }

    }
    catch {
        Write-Host "❌ Error processing request: $_"
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error (SQL Server)"
    }
}
