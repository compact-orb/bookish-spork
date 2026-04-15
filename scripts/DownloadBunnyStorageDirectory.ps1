<#
.SYNOPSIS
    Recursively downloads a directory from Bunny Storage to a local destination.

.DESCRIPTION
    This script connects to Bunny Storage using the provided credentials and recursively downloads
    all files and subdirectories from a specified remote path to a local destination.
    It uses parallel processing to improve performance when listing directories and downloading files.

    The script relies on the following environment variables:
    - BUNNY_STORAGE_ENDPOINT_CDN: The CDN endpoint for listing files.
    - BUNNY_STORAGE_ACCESS_KEY: The access key for authentication.
    - BUNNY_STORAGE_ENDPOINT: The storage endpoint for downloading files.

.PARAMETER Path
    The remote path in Bunny Storage to start downloading from.

.PARAMETER Destination
    The local directory where the files will be saved.

.PARAMETER ThrottleLimit
    The maximum number of concurrent threads to use for parallel operations. Default is 50.
#>
param(
    [string]$Path,
    [string]$Destination,
    [Int32]$ThrottleLimit = 50
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Initialize the list of directories to process with the starting path
$Directories = $Path
$Files = [System.Collections.Generic.List[string]]::new()

# Loop until there are no more directories to process
do {
    # Process directories in parallel to list their contents
    $Directories = $Directories | ForEach-Object -Parallel {
        if (-not (Test-Path Function:\Invoke-WithRetry)) {
            . "$using:PSScriptRoot/Invoke-WithRetry.ps1"
        }
        $currentPath = $_

        # List the contents of the current directory using the Bunny Storage API
        $response = Invoke-WithRetry -ActionName "list $currentPath" -MaxRetries 3 -ScriptBlock {
            Invoke-RestMethod -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT_CDN$currentPath/" -Headers @{ "accept" = "application/json"; "accesskey" = $using:env:BUNNY_STORAGE_ACCESS_KEY } -Method GET
        }

        $response | ForEach-Object {
            $Path = $_.Path

            if ($_.IsDirectory) {
                # If it's a directory, create the corresponding local directory
                New-Item -Path "$using:Destination$($Path.Substring($using:Path.Length))$($_.ObjectName)" -ItemType Directory | Out-Null

                # Return the directory path to be processed in the next iteration
                [PSCustomObject]@{
                    IsDirectory = $true;
                    Path        = "$($Path)$($_.ObjectName)"
                }
            }
            else {
                # If it's a file, return the file path to be added to the download list
                [PSCustomObject]@{
                    IsDirectory = $false;
                    Path        = "$($Path)$($_.ObjectName)"
                }
            }
        }
    } -ThrottleLimit $ThrottleLimit | ForEach-Object {
        if ($_.IsDirectory) {
            # Add subdirectory to the list for the next pass
            $_.Path
        }
        else {
            # Add file to the list of files to download
            $Files.Add($_.Path)
        }
    }
} while (![string]::IsNullOrWhiteSpace($Directories))

# Download all collected files in parallel
if ($Files.Count -gt 0) {
    $Files | ForEach-Object -Parallel {
        if (-not (Test-Path Function:\Invoke-WithRetry)) {
            . "$using:PSScriptRoot/Invoke-WithRetry.ps1"
        }
        $filePath = $_

        Invoke-WithRetry -ActionName "download $filePath" -MaxRetries 3 -ScriptBlock {
            # Download the file from Bunny Storage
            Invoke-WebRequest -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT$filePath" -Headers @{ accept = '*/*'; accesskey = $using:env:BUNNY_STORAGE_ACCESS_KEY } -OutFile "$using:Destination$($filePath.Substring($using:Path.Length))"

            Write-Output -InputObject "Downloaded $filePath to $using:Destination$($filePath.Substring($using:Path.Length))"
        }
    } -ThrottleLimit $ThrottleLimit
}
