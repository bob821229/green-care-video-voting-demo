using Microsoft.Extensions.Options;

namespace GreenCare.Api.Infrastructure;

public enum ActivityState
{
    Upcoming,
    Active,
    Ended
}

public sealed record ActivityStatus(ActivityState State, DateTimeOffset StartsAt, DateTimeOffset EndsAt);

public interface IActivityService
{
    ActivityStatus GetStatus();
}

public sealed class ActivityService(IOptions<ActivityOptions> options, TimeProvider timeProvider) : IActivityService
{
    public ActivityStatus GetStatus()
    {
        var now = timeProvider.GetUtcNow();
        var state = now < options.Value.StartsAt
            ? ActivityState.Upcoming
            : now >= options.Value.EndsAt
                ? ActivityState.Ended
                : ActivityState.Active;

        return new ActivityStatus(state, options.Value.StartsAt, options.Value.EndsAt);
    }
}
