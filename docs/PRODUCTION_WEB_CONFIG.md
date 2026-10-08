# 正式站 web.config 準備與檢查

正式站設定範本位於 `deploy/web.config.production.template`。範本不得直接部署；真實秘密只能在正式伺服器的受控副本中填入，不得提交 Git、貼入文件或傳送到對話。

## 已固定的正式值

- Environment：`Production`
- Host：`greencare.triwra.org.tw`
- SQL Server：`labdb`
- Database：`GreenCare_Production`
- Database user：`GreenCare_Production_User`
- Data Protection：`D:\Webs_SSL\greencare_shared\production-keys`
- CAPTCHA hostname：`greencare.triwra.org.tw`
- 活動期間由 `appsettings.Production.json` 提供；正式 `web.config` 禁止出現 `Activity__StartsAt` 或 `Activity__EndsAt`。

## 伺服器端填入項目

在發布包的 `web.config` 副本填入下列四個占位符：

- `__PRODUCTION_SQL_PASSWORD__`
- `__PRODUCTION_APP_SECRET__`
- `__PRODUCTION_CAPTCHA_SITE_KEY__`
- `__PRODUCTION_CAPTCHA_SECRET_KEY__`

若秘密包含 XML 特殊字元，必須進行 XML attribute escaping。此次 SQL 密碼與 AppSecret 使用 Base64，可直接放入；仍應以 XML 解析檢查為準。

## 離線檢查

以下 PowerShell 只回報結構與布林值，不輸出任何秘密內容：

```powershell
$configPath = 'D:\Webs_SSL\greencare_staging\web.config'
[xml]$configXml = Get-Content -LiteralPath $configPath -Raw

$variables = @(
    $configXml.configuration.location.'system.webServer'.aspNetCore.environmentVariables.environmentVariable
)
$duplicateNames = $variables |
    Group-Object name |
    Where-Object Count -gt 1 |
    Select-Object -ExpandProperty Name
$valuesByName = @{}
foreach ($variable in $variables) {
    $valuesByName[[string]$variable.name] = [string]$variable.value
}

$requiredNames = @(
    'ASPNETCORE_ENVIRONMENT',
    'AllowedHosts',
    'ConnectionStrings__GreenCare',
    'Security__AppSecret',
    'Security__DataProtectionKeysPath',
    'Captcha__SiteKey',
    'Captcha__SecretKey',
    'Captcha__ExpectedHostname'
)

[pscustomobject]@{
    XmlParsed                 = $true
    DuplicateNames           = ($duplicateNames -join ', ')
    RequiredNamesPresent     = (@($requiredNames | Where-Object { -not $valuesByName.ContainsKey($_) }).Count -eq 0)
    PlaceholderCount         = ([regex]::Matches((Get-Content -LiteralPath $configPath -Raw), '__PRODUCTION_[A-Z_]+__')).Count
    EnvironmentIsProduction  = ($valuesByName['ASPNETCORE_ENVIRONMENT'] -eq 'Production')
    AllowedHostIsProduction  = ($valuesByName['AllowedHosts'] -eq 'greencare.triwra.org.tw')
    DatabaseIsProduction     = ($valuesByName['ConnectionStrings__GreenCare'] -match 'Database=GreenCare_Production(?:;|$)')
    DatabaseUserIsProduction = ($valuesByName['ConnectionStrings__GreenCare'] -match 'User ID=GreenCare_Production_User(?:;|$)')
    KeysPathIsProduction     = ($valuesByName['Security__DataProtectionKeysPath'] -eq 'D:\Webs_SSL\greencare_shared\production-keys')
    AppSecretLength          = $valuesByName['Security__AppSecret'].Length
    CaptchaHostIsProduction  = ($valuesByName['Captcha__ExpectedHostname'] -eq 'greencare.triwra.org.tw')
    HasActivityOverrides     = ($variables.name -match '^Activity__').Count -gt 0
}
```

通過標準：

- `DuplicateNames` 為空白。
- `RequiredNamesPresent` 為 `True`。
- `PlaceholderCount` 為 `0`。
- 所有 Production 判斷為 `True`。
- `AppSecretLength` 為 `64`。
- `HasActivityOverrides` 為 `False`。

完成離線檢查前，不得覆蓋正式站既有預告頁或回收正式 App Pool。
