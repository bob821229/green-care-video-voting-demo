namespace GreenCare.Api.Infrastructure;

public sealed class SecurityOptions
{
    public const string SectionName = "Security";

    public string AppSecret { get; init; } = string.Empty;
    public string DataProtectionKeysPath { get; init; } = string.Empty;
    public string DeviceCookieName { get; init; } = "vote_device";
}
