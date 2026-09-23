using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Data;

public sealed class GreenCareDbContext(DbContextOptions<GreenCareDbContext> options) : DbContext(options)
{
    public DbSet<SchemaVersion> SchemaVersions => Set<SchemaVersion>();
    public DbSet<Video> Videos => Set<Video>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<WatchSession> WatchSessions => Set<WatchSession>();
    public DbSet<Vote> Votes => Set<Vote>();
    public DbSet<RiskEvent> RiskEvents => Set<RiskEvent>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GreenCareDbContext).Assembly);
    }
}
