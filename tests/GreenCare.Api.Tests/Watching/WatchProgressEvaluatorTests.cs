using GreenCare.Api.Features.Watching;

namespace GreenCare.Api.Tests.Watching;

public sealed class WatchProgressEvaluatorTests
{
    [Fact]
    public void Normal_foreground_playback_reaches_eighty_percent()
    {
        var result = Evaluate(79, 79, 5, position: 80, playing: true, visible: true, rate: 1);
        Assert.True(result.Qualified);
        Assert.Equal(80.5m, result.WatchedSeconds);
    }

    [Theory]
    [InlineData(false, true, 1)]
    [InlineData(true, false, 1)]
    [InlineData(true, true, 1.5)]
    public void Background_pause_or_abnormal_speed_does_not_accumulate(bool playing, bool visible, double rate)
    {
        var result = Evaluate(10, 10, 5, position: 15, playing, visible, rate);
        Assert.Equal(10m, result.WatchedSeconds);
    }

    [Fact]
    public void Large_forward_jump_does_not_accumulate()
    {
        var result = Evaluate(10, 10, 5, position: 70, playing: true, visible: true, rate: 1);
        Assert.Equal(10m, result.WatchedSeconds);
    }

    [Fact]
    public void Return_to_start_is_marked_as_restart_without_duplicate_progress()
    {
        var result = Evaluate(40, 70, 5, position: 2, playing: true, visible: true, rate: 1);
        Assert.True(result.Restarted);
        Assert.Equal(40m, result.WatchedSeconds);
        Assert.Equal(2m, result.LastPositionSeconds);
    }

    [Fact]
    public void Tick_under_three_seconds_is_throttled_but_transition_is_not()
    {
        var tick = Evaluate(10, 10, 1, position: 11, playing: true, visible: true, rate: 1);
        var transition = WatchProgressEvaluator.Evaluate(
            100, 10, 10, 1,
            new WatchProgressRequest("token", 11, 1, true, true, "transition"));
        Assert.True(tick.Throttled);
        Assert.False(transition.Throttled);
    }

    private static WatchProgressDecision Evaluate(
        decimal watched,
        decimal lastPosition,
        double elapsed,
        double position,
        bool playing,
        bool visible,
        double rate) =>
        WatchProgressEvaluator.Evaluate(
            100, watched, lastPosition, elapsed,
            new WatchProgressRequest("token", position, rate, playing, visible, "tick"));
}
