namespace GreenCare.Api.Data.Entities;

public sealed class Video
{
    public byte Id { get; set; }
    public string Number { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Team { get; set; } = string.Empty;
    public string YoutubeId { get; set; } = string.Empty;
    public string Poster { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public byte SortOrder { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }

    public ICollection<WatchSession> WatchSessions { get; set; } = [];
    public ICollection<Vote> Votes { get; set; } = [];
}
