param(
    [Parameter(Mandatory = $true)]
    [string]$TargetOrg
)

$accessKey = $env:UNSPLASH_ACCESS_KEY
if ([string]::IsNullOrWhiteSpace($accessKey)) {
    throw 'Set UNSPLASH_ACCESS_KEY before running this script.'
}

$requestBody = @{
    authenticationProtocol = 'Custom'
    credentials = @{
        AccessKey = $accessKey
    }
    externalCredential = 'Unsplash_API_Key'
    principalName = 'Unsplash_Principal'
    principalType = 'NamedPrincipal'
} | ConvertTo-Json -Compress

$requestBody | sf api request rest '/services/data/v67.0/named-credentials/credential' --target-org $TargetOrg --header 'Content-Type: application/json' --body - --method POST
