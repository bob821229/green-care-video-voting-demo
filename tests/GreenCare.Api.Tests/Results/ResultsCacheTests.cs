using GreenCare.Api.Features.ResultData;
using GreenCare.Api.Infrastructure;

namespace GreenCare.Api.Tests.Results;

public sealed class ResultsCacheTests
{
    [Fact]
    public async Task Reuses_payload_for_five_seconds()
    {
        var time = new MutableTimeProvider(DateTimeOffset.UnixEpoch);
        var cache = new ResultsCache(time);
        var calls = 0;

        var first = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);
        time.Advance(TimeSpan.FromSeconds(4));
        var second = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);

        Assert.Same(first, second);
        Assert.Equal(1, calls);
    }

    [Fact]
    public async Task Refreshes_payload_after_five_seconds()
    {
        var time = new MutableTimeProvider(DateTimeOffset.UnixEpoch);
        var cache = new ResultsCache(time);
        var calls = 0;

        var first = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);
        time.Advance(TimeSpan.FromSeconds(5));
        var second = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);

        Assert.NotSame(first, second);
        Assert.Equal(2, calls);
    }

    [Fact]
    public async Task Invalidate_forces_an_immediate_refresh()
    {
        var cache = new ResultsCache(new MutableTimeProvider(DateTimeOffset.UnixEpoch));
        var calls = 0;

        var first = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);
        cache.Invalidate();
        var second = await cache.GetOrCreateAsync(() => Task.FromResult(Payload(++calls)), default);

        Assert.NotSame(first, second);
        Assert.Equal(2, calls);
    }

    private static ResultsPayload Payload(int marker) => new(
        false, true, DateTime.UnixEpoch.AddSeconds(marker),
        new ResultsActivity("active", DateTime.UnixEpoch, DateTime.UnixEpoch.AddDays(1)),
        new ResultsGroups(Array.Empty<RankedVideo>(), Array.Empty<RankedVideo>()));

    private sealed class MutableTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
        public void Advance(TimeSpan duration) => now = now.Add(duration);
    }
}
