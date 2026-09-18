namespace GreenCare.Api.Data.Entities;

public sealed class RiskEvent
{
    public long Id { get; set; }
    public Guid? DeviceId { get; set; }
    public byte[]? IpHash { get; set; }
    public string Kind { get; set; } = string.Empty;
    public string? DetailJson { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public Device? Device { get; set; }
}
