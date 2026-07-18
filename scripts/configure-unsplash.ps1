param(
    [Parameter(Mandatory = $true)]
    [string]$TargetOrg,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

if ($TargetOrg -eq '--') {
    if ($RemainingArguments.Count -ne 1) {
        throw 'Provide exactly one target org.'
    }

    $TargetOrg = $RemainingArguments[0]
} elseif ($RemainingArguments.Count -gt 0) {
    throw 'Provide exactly one target org.'
}

$accessKey = $env:UNSPLASH_ACCESS_KEY
if ([string]::IsNullOrWhiteSpace($accessKey)) {
    throw 'Set UNSPLASH_ACCESS_KEY before running this script.'
}

$requestBody = @{
    authenticationProtocol = 'Custom'
    credentials = @{
        AccessKey = @{
            value = $accessKey
            encrypted = $true
        }
    }
    externalCredential = 'Unsplash_API_Key'
    principalName = 'Unsplash_Principal'
    principalType = 'NamedPrincipal'
} | ConvertTo-Json -Compress -Depth 5

$requestBody | sf api request rest '/services/data/v67.0/named-credentials/credential' --target-org $TargetOrg --header 'Content-Type: application/json' --body - --method POST
