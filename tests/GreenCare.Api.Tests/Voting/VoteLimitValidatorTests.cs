using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Features.Voting;

namespace GreenCare.Api.Tests.Voting;

public sealed class VoteLimitValidatorTests
{
    private static readonly Guid CurrentDeviceId = Guid.NewGuid();
    private static readonly Guid OtherBrowserDeviceId = Guid.NewGuid();

    [Fact]
    public void Rejects_same_video_voted_from_another_browser_environment_match()
    {
        var error = VoteLimitValidator.Validate(
            [Vote(OtherBrowserDeviceId, 1, VoteCategories.Individual)],
            Video(1),
            CurrentDeviceId);

        Assert.Equal("此裝置與網路環境已投過這支作品。", error);
    }

    [Fact]
    public void Rejects_third_group_vote_across_browser_device_ids()
    {
        var error = VoteLimitValidator.Validate(
            [
                Vote(CurrentDeviceId, 1, VoteCategories.Individual),
                Vote(OtherBrowserDeviceId, 2, VoteCategories.Individual)
            ],
            Video(3),
            CurrentDeviceId);

        Assert.Equal(
            "此裝置與網路環境已使用個人組兩票，投票送出後無法取消或改投。",
            error);
    }

    [Fact]
    public void Cancelled_and_void_votes_do_not_consume_environment_quota()
    {
        var cancelled = Vote(OtherBrowserDeviceId, 1, VoteCategories.Individual, VoteStatuses.Cancelled);
        var voided = Vote(OtherBrowserDeviceId, 2, VoteCategories.Individual, VoteStatuses.Void);

        var error = VoteLimitValidator.Validate(
            [cancelled, voided],
            Video(3),
            CurrentDeviceId);

        Assert.Null(error);
    }

    [Fact]
    public void Allows_second_group_vote_for_same_environment()
    {
        var error = VoteLimitValidator.Validate(
            [Vote(OtherBrowserDeviceId, 1, VoteCategories.Individual)],
            Video(2),
            CurrentDeviceId);

        Assert.Null(error);
    }

    private static Vote Vote(Guid deviceId, byte videoId, string category, string status = VoteStatuses.Valid) => new()
    {
        DeviceId = deviceId,
        VideoId = videoId,
        Category = category,
        Status = status
    };

    private static VideoItem Video(int id) => new(
        id,
        id.ToString("00"),
        $"作品 {id}",
        "測試團隊",
        "video-id",
        "poster.jpg");
}
