namespace GreenCare.Api.Data.Entities;

public sealed class Device
{
    public Guid Id { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastSeenAtUtc { get; set; }

    public ICollection<WatchSession> WatchSessions { get; set; } = [];
    public ICollection<Vote> Votes { get; set; } = [];
    public ICollection<RiskEvent> RiskEvents { get; set; } = [];
}
