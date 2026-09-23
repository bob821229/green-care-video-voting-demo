using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Tests.Data;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class GreenCareDbContextIntegrationTests
{
    private const string DefaultConnectionString =
        "Server=(localdb)\\MSSQLLocalDB;Database=GreenCare_Development;Integrated Security=true;TrustServerCertificate=true";

    [Fact]
    public async Task Crud_and_database_constraints_work_against_real_sql_server()
    {
        await using var context = CreateContext();
        await using var transaction = await context.Database.BeginTransactionAsync();

        var now = DateTime.UtcNow;
        var device = new Device
        {
            Id = Guid.NewGuid(),
            CreatedAtUtc = now,
            LastSeenAtUtc = now
        };
        var watchSession = new WatchSession
        {
            Id = Guid.NewGuid(),
            DeviceId = device.Id,
            VideoId = 1,
            DurationSeconds = 100m,
            WatchedSeconds = 80m,
            LastPositionSeconds = 80m,
            LastPingAtUtc = now,
            QualifiedAtUtc = now,
            CreatedAtUtc = now
        };
        var vote = new Vote
        {
            DeviceId = device.Id,
            VideoId = 1,
            Category = VoteCategories.Individual,
            WatchSessionId = watchSession.Id,
            IpHash = Enumerable.Repeat((byte)1, 32).ToArray(),
            RiskScore = 0,
            Status = VoteStatuses.Valid,
            CreatedAtUtc = now
        };

        context.AddRange(device, watchSession, vote);
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();

        var storedVote = await context.Votes.AsNoTracking().SingleAsync(x => x.Id == vote.Id);
        Assert.True(storedVote.IsActive);

        var storedDevice = await context.Devices.SingleAsync(x => x.Id == device.Id);
        storedDevice.LastSeenAtUtc = now.AddSeconds(1);
        await context.SaveChangesAsync();

        context.Votes.Add(new Vote
        {
            DeviceId = device.Id,
            VideoId = 1,
            Category = VoteCategories.Individual,
            WatchSessionId = watchSession.Id,
            IpHash = Enumerable.Repeat((byte)2, 32).ToArray(),
            RiskScore = 0,
            Status = VoteStatuses.Flagged,
            CreatedAtUtc = now
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => context.SaveChangesAsync());
        await transaction.RollbackAsync();
    }

    [Fact]
    public async Task Explicit_transaction_rollback_leaves_no_data()
    {
        await using var context = CreateContext();
        var target = $"integration-{Guid.NewGuid():N}";

        await using (var transaction = await context.Database.BeginTransactionAsync())
        {
            context.AuditLogs.Add(new AuditLog
            {
                Action = "integration-test",
                Target = target,
                DetailJson = "{\"rolledBack\":true}",
                CreatedAtUtc = DateTime.UtcNow
            });
            await context.SaveChangesAsync();
            await transaction.RollbackAsync();
        }

        context.ChangeTracker.Clear();
        Assert.False(await context.AuditLogs.AsNoTracking().AnyAsync(x => x.Target == target));
    }

    [Fact]
    public async Task Delete_respects_relationship_order_and_removes_graph()
    {
        await using var context = CreateContext();
        await using var transaction = await context.Database.BeginTransactionAsync();
        var now = DateTime.UtcNow;
        var deviceId = Guid.NewGuid();
        var watchSessionId = Guid.NewGuid();
        var device = new Device { Id = deviceId, CreatedAtUtc = now, LastSeenAtUtc = now };
        var watchSession = new WatchSession
        {
            Id = watchSessionId,
            DeviceId = deviceId,
            VideoId = 16,
            DurationSeconds = 100m,
            WatchedSeconds = 80m,
            LastPositionSeconds = 80m,
            LastPingAtUtc = now,
            QualifiedAtUtc = now,
            CreatedAtUtc = now
        };
        var vote = new Vote
        {
            DeviceId = deviceId,
            VideoId = 16,
            Category = VoteCategories.Team,
            WatchSessionId = watchSessionId,
            IpHash = Enumerable.Repeat((byte)3, 32).ToArray(),
            Status = VoteStatuses.Valid,
            CreatedAtUtc = now
        };

        context.AddRange(device, watchSession, vote);
        await context.SaveChangesAsync();

        context.Remove(vote);
        context.Remove(watchSession);
        context.Remove(device);
        await context.SaveChangesAsync();

        Assert.False(await context.Devices.AsNoTracking().AnyAsync(x => x.Id == deviceId));
        await transaction.RollbackAsync();
    }

    [Fact]
    public async Task Manual_schema_versions_are_available_without_automatic_migration()
    {
        await using var context = CreateContext();
        var versions = await context.SchemaVersions
            .AsNoTracking()
            .Where(x => x.VersionNumber == "001" || x.VersionNumber == "002" || x.VersionNumber == "003")
            .Select(x => x.VersionNumber)
            .ToListAsync();

        Assert.Contains("001", versions);
        Assert.Contains("002", versions);
        Assert.Contains("003", versions);
    }

    [Fact]
    public async Task Video_catalog_contains_the_seeded_thirty_entries()
    {
        await using var context = CreateContext();
        var videos = await context.Videos.AsNoTracking().OrderBy(x => x.Id).ToListAsync();

        Assert.Equal(30, videos.Count);
        Assert.Equal(15, videos.Count(x => x.Category == VoteCategories.Individual));
        Assert.Equal(15, videos.Count(x => x.Category == VoteCategories.Team));
        Assert.Equal("01", videos[0].Number);
        Assert.Equal("30", videos[^1].Number);
    }

    private static GreenCareDbContext CreateContext()
    {
        var connectionString = Environment.GetEnvironmentVariable("GREENCARE_TEST_SQLSERVER")
            ?? DefaultConnectionString;
        var options = new DbContextOptionsBuilder<GreenCareDbContext>()
            .UseSqlServer(connectionString)
            .Options;
        return new GreenCareDbContext(options);
    }
}
