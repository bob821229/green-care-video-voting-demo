namespace GreenCare.Api.Tests;

public sealed class ActivityOptionsTests
{
    [Fact]
    public void Production_activity_period_matches_the_confirmed_schedule()
    {
        var options = new ActivityOptions
        {
            StartsAt = DateTimeOffset.Parse("2026-10-12T10:00:00+08:00"),
            EndsAt = DateTimeOffset.Parse("2026-10-23T17:00:00+08:00")
        };

        Assert.Equal(TimeSpan.FromHours(8), options.StartsAt.Offset);
        Assert.Equal(new DateTime(2026, 10, 12, 10, 0, 0), options.StartsAt.DateTime);
        Assert.Equal(new DateTime(2026, 10, 23, 17, 0, 0), options.EndsAt.DateTime);
        Assert.True(options.EndsAt > options.StartsAt);
    }
}
