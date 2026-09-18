namespace GreenCare.Api.Data.Entities;

public sealed class Vote
{
    public long Id { get; set; }
    public Guid DeviceId { get; set; }
    public byte VideoId { get; set; }
    public string Category { get; set; } = string.Empty;
    public Guid WatchSessionId { get; set; }
    public byte[] IpHash { get; set; } = [];
    public byte[]? DeviceSignalHash { get; set; }
    public byte RiskScore { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? CancelledAtUtc { get; set; }
    public long? ReplacedByVoteId { get; set; }
    public DateTime? VoidedAtUtc { get; set; }
    public string? VoidReason { get; set; }
    public bool IsActive { get; private set; }

    public Device Device { get; set; } = null!;
    public WatchSession WatchSession { get; set; } = null!;
    public Vote? ReplacedByVote { get; set; }
    public ICollection<Vote> ReplacedVotes { get; set; } = [];
}
