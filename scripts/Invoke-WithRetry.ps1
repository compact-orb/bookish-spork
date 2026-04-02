function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [int]$MaxRetries = 3,
        [string]$ActionName = "Operation"
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            # Execute the provided script block
            & $ScriptBlock
            # If successful, break out of the loop
            break
        }
        catch {
            if ($attempt -eq $MaxRetries) {
                Write-Error -Message "Failed to $ActionName after $MaxRetries attempts: $_"
                throw
            }
            Write-Warning -Message "Attempt $attempt/$MaxRetries failed for $ActionName`: $($_.Exception.Message). Retrying..."
        }
    }
}
