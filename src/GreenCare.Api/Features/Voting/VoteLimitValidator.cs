using GreenCare.Api.Data.Entities;
using GreenCare.Api.Features.Videos;

namespace GreenCare.Api.Features.Voting;

public static class VoteLimitValidator
{
    public static string? Validate(IReadOnlyCollection<Vote> votes, VideoItem video, Guid deviceId)
    {
        var activeVotes = votes
            .Where(x => x.Status is VoteStatuses.Valid or VoteStatuses.Flagged)
            .ToArray();

        var duplicate = activeVotes.FirstOrDefault(x => x.VideoId == video.Id);
        if (duplicate is not null)
        {
            return duplicate.DeviceId == deviceId
                ? "你已經投過這支作品。"
                : "此裝置與網路環境已投過這支作品。";
        }

        if (activeVotes.Count(x => x.Category == video.Category) >= 2)
        {
            var group = video.Category == VoteCategories.Individual ? "個人組" : "團體組";
            return activeVotes.Any(x => x.Category == video.Category && x.DeviceId != deviceId)
                ? $"此裝置與網路環境已使用{group}兩票，投票送出後無法取消或改投。"
                : $"{group}已使用兩票，投票送出後無法取消或改投。";
        }

        return null;
    }
}
