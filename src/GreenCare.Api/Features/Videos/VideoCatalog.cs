using GreenCare.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Videos;

public sealed record VideoItem(int Id, string Number, string Title, string Team, string YoutubeId, string Poster)
{
    public string Category => Id <= 15 ? "individual" : "team";
}

public interface IVideoCatalog
{
    Task<IReadOnlyList<VideoItem>> GetAllAsync(CancellationToken cancellationToken);
    Task<bool> ContainsAsync(int id, CancellationToken cancellationToken);
    Task<VideoItem?> FindAsync(int id, CancellationToken cancellationToken);
}

public sealed class VideoCatalog(GreenCareDbContext db) : IVideoCatalog
{
    public async Task<IReadOnlyList<VideoItem>> GetAllAsync(CancellationToken cancellationToken) =>
        await db.Videos.AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.Category)
            .ThenBy(x => x.SortOrder)
            .Select(x => new VideoItem(x.Id, x.Number, x.Title, x.Team, x.YoutubeId, x.Poster))
            .ToListAsync(cancellationToken);

    public Task<bool> ContainsAsync(int id, CancellationToken cancellationToken) =>
        db.Videos.AsNoTracking().AnyAsync(x => x.Id == id && x.IsActive, cancellationToken);

    public Task<VideoItem?> FindAsync(int id, CancellationToken cancellationToken) =>
        db.Videos.AsNoTracking()
            .Where(x => x.Id == id && x.IsActive)
            .Select(x => new VideoItem(x.Id, x.Number, x.Title, x.Team, x.YoutubeId, x.Poster))
            .SingleOrDefaultAsync(cancellationToken);
}
