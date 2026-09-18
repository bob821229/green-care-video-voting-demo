namespace GreenCare.Api.Data.Entities;

public sealed class AuditLog
{
    public long Id { get; set; }
    public string Action { get; set; } = string.Empty;
    public string Target { get; set; } = string.Empty;
    public string? DetailJson { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
