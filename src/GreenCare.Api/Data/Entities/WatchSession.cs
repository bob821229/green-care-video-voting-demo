namespace GreenCare.Api.Data.Entities;

public sealed class WatchSession
{
    public Guid Id { get; set; }
    public Guid DeviceId { get; set; }
    public byte VideoId { get; set; }
    public decimal DurationSeconds { get; set; }
    public decimal WatchedSeconds { get; set; }
    public decimal LastPositionSeconds { get; set; }
    public DateTime LastPingAtUtc { get; set; }
    public DateTime? QualifiedAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }

    public Device Device { get; set; } = null!;
    public ICollection<Vote> Votes { get; set; } = [];
}
