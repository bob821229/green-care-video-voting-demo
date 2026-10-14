using GreenCare.Api.Features.Videos;
using GreenCare.Api.Features.Watching;

namespace GreenCare.Api.Tests.Watching;

public sealed class ClientWatchProgressWriterTests
{
    private static readonly VideoItem Video = new(1, "01", "作品", "參賽者", "youtube-id", "poster.jpg", "individual");

    [Fact]
    public void Accepts_matching_progress_at_eighty_percent()
    {
        var request = new ClientWatchProgressRequest(1, "youtube-id", 100, 80, 80);
        Assert.Null(ClientWatchProgressWriter.ValidateQualified(request, Video));
    }

    [Theory]
    [InlineData(79.999)]
    [InlineData(-1)]
    [InlineData(101)]
    public void Rejects_unqualified_or_invalid_watched_seconds(double watched)
    {
        var request = new ClientWatchProgressRequest(1, "youtube-id", 100, watched, 80);
        Assert.NotNull(ClientWatchProgressWriter.ValidateQualified(request, Video));
    }

    [Fact]
    public void Rejects_progress_for_another_youtube_video()
    {
        var request = new ClientWatchProgressRequest(1, "different", 100, 80, 80);
        Assert.Equal("觀看進度資料與作品不符，請重新開啟影片。", ClientWatchProgressWriter.ValidateQualified(request, Video));
    }
}
