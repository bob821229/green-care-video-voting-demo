namespace GreenCare.Api.Features.Watching;

public sealed record WatchStartRequest(int VideoId, double Duration);
public sealed record WatchStartResponse(string SessionId, bool Reused);
public sealed record WatchProgressRequest(
    string? SessionId,
    double Position,
    double PlaybackRate,
    bool Playing,
    bool Visible,
    string? Event);
