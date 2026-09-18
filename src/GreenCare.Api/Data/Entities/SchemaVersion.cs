namespace GreenCare.Api.Data.Entities;

public sealed class SchemaVersion
{
    public string VersionNumber { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime AppliedAtUtc { get; set; }
    public string AppliedBy { get; set; } = string.Empty;
}
