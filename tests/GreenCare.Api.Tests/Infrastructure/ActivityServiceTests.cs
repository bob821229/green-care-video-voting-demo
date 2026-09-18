using GreenCare.Api.Infrastructure;
using Microsoft.Extensions.Options;

namespace GreenCare.Api.Tests.Infrastructure;

public sealed class ActivityServiceTests
{
    private static readonly DateTimeOffset Start = DateTimeOffset.Parse("2026-10-12T10:00:00+08:00");
    private static readonly DateTimeOffset End = DateTimeOffset.Parse("2026-10-23T17:00:00+08:00");

    [Theory]
    [InlineData("2026-10-12T01:59:59Z", ActivityState.Upcoming)]
    [InlineData("2026-10-12T02:00:00Z", ActivityState.Active)]
    [InlineData("2026-10-23T08:59:59Z", ActivityState.Active)]
    [InlineData("2026-10-23T09:00:00Z", ActivityState.Ended)]
    public void Uses_confirmed_taipei_boundaries(string utcNow, ActivityState expected)
    {
        var service = new ActivityService(
            Options.Create(new ActivityOptions { StartsAt = Start, EndsAt = End }),
            new FixedTimeProvider(DateTimeOffset.Parse(utcNow)));

        Assert.Equal(expected, service.GetStatus().State);
    }

    private sealed class FixedTimeProvider(DateTimeOffset utcNow) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => utcNow;
    }
}
