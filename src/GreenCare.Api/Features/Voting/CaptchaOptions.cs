namespace GreenCare.Api.Features.Voting;

public sealed class CaptchaOptions
{
    public const string SectionName = "Captcha";
    public string SiteKey { get; init; } = string.Empty;
    public string SecretKey { get; init; } = string.Empty;
    public string ExpectedHostname { get; init; } = string.Empty;
}
