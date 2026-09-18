using Microsoft.Extensions.Options;

namespace GreenCare.Api.Infrastructure;

public sealed class SecurityOptionsValidator(IHostEnvironment environment) : IValidateOptions<SecurityOptions>
{
    public ValidateOptionsResult Validate(string? name, SecurityOptions options)
    {
        var errors = new List<string>();
        if (options.AppSecret.Length < 32)
        {
            errors.Add("Security:AppSecret must contain at least 32 characters.");
        }

        if (environment.IsProduction() &&
            options.AppSecret.StartsWith("development-", StringComparison.OrdinalIgnoreCase))
        {
            errors.Add("Production cannot use a development AppSecret.");
        }

        if (string.IsNullOrWhiteSpace(options.DataProtectionKeysPath))
        {
            errors.Add("Security:DataProtectionKeysPath is required.");
        }

        if (string.IsNullOrWhiteSpace(options.DeviceCookieName))
        {
            errors.Add("Security:DeviceCookieName is required.");
        }

        return errors.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(errors);
    }
}
