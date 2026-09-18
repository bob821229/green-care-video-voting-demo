namespace GreenCare.Api.Features.Watching;

public sealed record WatchProgressDecision(
    decimal WatchedSeconds,
    decimal LastPositionSeconds,
    bool Qualified,
    bool Restarted,
    bool Throttled,
    bool ShouldPersist);

public static class WatchProgressEvaluator
{
    public static WatchProgressDecision Evaluate(
        decimal duration,
        decimal watched,
        decimal lastPosition,
        double elapsedSeconds,
        WatchProgressRequest request)
    {
        var position = request.Position;
        var restarted = double.IsFinite(position) &&
                        (double)lastPosition - position > Math.Max(5, (double)duration * .1) &&
                        position <= Math.Max(10, (double)duration * .15);
        if (restarted)
            return new(watched, (decimal)position, watched / duration >= .8m, true, false, true);

        if (elapsedSeconds < 3 && !string.Equals(request.Event, "transition", StringComparison.Ordinal))
            return new(watched, lastPosition, watched / duration >= .8m, false, true, false);

        var wall = Math.Clamp(elapsedSeconds, 0, 10);
        var delta = position - (double)lastPosition;
        var plausible = double.IsFinite(position) && request.Playing && request.Visible &&
                        request.PlaybackRate is > 0 and <= 1.25 && delta >= 0 && delta <= wall * 1.6 + 1;
        var nextWatched = Math.Min((double)duration, (double)watched + (plausible ? Math.Min(wall, delta + .5) : 0));
        var nextPosition = double.IsFinite(position) && position >= 0 && position <= (double)duration
            ? (decimal)position
            : lastPosition;
        return new((decimal)nextWatched, nextPosition, nextWatched / (double)duration >= .8, false, false, true);
    }
}
