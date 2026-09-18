using System.Text.Json;

namespace GreenCare.Api.Features.Videos;

public sealed record VideoItem(int Id, string Number, string Title, string Team, string YoutubeId, string Poster)
{
    public string Category => Id <= 15 ? "individual" : "team";
}

public interface IVideoCatalog
{
    IReadOnlyList<VideoItem> All { get; }
    bool Contains(int id);
    VideoItem? Find(int id);
}

public sealed class VideoCatalog : IVideoCatalog
{
    private readonly Dictionary<int, VideoItem> _byId;
    public IReadOnlyList<VideoItem> All { get; }

    public VideoCatalog()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "videos.json");
        var items = JsonSerializer.Deserialize<List<VideoItem>>(
            File.ReadAllText(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("videos.json is empty.");
        if (items.Count != 30 || items.Select(x => x.Id).Distinct().Count() != 30 || items.Any(x => x.Id is < 1 or > 30))
            throw new InvalidOperationException("videos.json must contain unique video IDs 1 through 30.");
        All = items.OrderBy(x => x.Id).ToArray();
        _byId = All.ToDictionary(x => x.Id);
    }

    public bool Contains(int id) => _byId.ContainsKey(id);
    public VideoItem? Find(int id) => _byId.GetValueOrDefault(id);
}
