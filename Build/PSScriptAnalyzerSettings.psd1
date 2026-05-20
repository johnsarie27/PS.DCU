@{
    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true
    ExcludeRules        = @(
        'PSAvoidGlobalVars'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
