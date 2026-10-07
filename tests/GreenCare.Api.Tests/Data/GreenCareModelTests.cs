using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace GreenCare.Api.Tests.Data;

public sealed class GreenCareModelTests
{
    private readonly IModel _model = CreateContext().Model;

    [Fact]
    public void Model_maps_all_tables_from_manual_schema()
    {
        AssertTable<SchemaVersion>("SchemaVersions");
        AssertTable<Video>("Videos");
        AssertTable<Device>("Devices");
        AssertTable<WatchSession>("WatchSessions");
        AssertTable<Vote>("Votes");
        AssertTable<RiskEvent>("RiskEvents");
        AssertTable<AuditLog>("AuditLogs");
    }

    [Fact]
    public void Vote_mapping_matches_computed_column_and_filtered_unique_index()
    {
        var entity = _model.FindEntityType(typeof(Vote));
        Assert.NotNull(entity);

        var table = StoreObjectIdentifier.Table("Votes", "dbo");
        var isActive = entity.FindProperty(nameof(Vote.IsActive));
        Assert.NotNull(isActive);
        Assert.True(isActive.GetComputedColumnSql(table)?.Contains("CASE WHEN", StringComparison.Ordinal) == true);
        Assert.True(isActive.GetIsStored(table));

        var index = entity.GetIndexes().Single(x => x.GetDatabaseName() == "UX_Votes_Device_Video_Active");
        Assert.True(index.IsUnique);
        Assert.Equal(
            "[CancelledAtUtc] IS NULL AND [VoidedAtUtc] IS NULL",
            index.GetFilter());

        var environmentIndex = entity.GetIndexes()
            .Single(x => x.GetDatabaseName() == "IX_Votes_Environment_Category_Status");
        Assert.Equal(
            new[]
            {
                nameof(Vote.IpHash),
                nameof(Vote.DeviceSignalHash),
                nameof(Vote.Category),
                nameof(Vote.Status)
            },
            environmentIndex.Properties.Select(x => x.Name));
    }

    [Fact]
    public void Relationships_never_cascade_delete_business_data()
    {
        var businessTypes = new[] { typeof(WatchSession), typeof(Vote), typeof(RiskEvent) };
        var foreignKeys = businessTypes
            .SelectMany(type => _model.FindEntityType(type)!.GetForeignKeys())
            .ToArray();

        Assert.NotEmpty(foreignKeys);
        Assert.All(foreignKeys, foreignKey => Assert.Equal(DeleteBehavior.NoAction, foreignKey.DeleteBehavior));
    }

    private void AssertTable<TEntity>(string tableName)
    {
        var entity = _model.FindEntityType(typeof(TEntity));
        Assert.NotNull(entity);
        Assert.Equal(tableName, entity.GetTableName());
        Assert.Equal("dbo", entity.GetSchema());
    }

    private static GreenCareDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<GreenCareDbContext>()
            .UseSqlServer("Server=(localdb)\\MSSQLLocalDB;Database=ModelOnly;Integrated Security=true")
            .Options;
        return new GreenCareDbContext(options);
    }
}
