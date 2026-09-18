namespace GreenCare.Api.Infrastructure;

public sealed class ForwardedHeadersSettings
{
    public const string SectionName = "ForwardedHeaders";

    public string[] KnownProxies { get; init; } = [];
    public int ForwardLimit { get; init; } = 1;
}
