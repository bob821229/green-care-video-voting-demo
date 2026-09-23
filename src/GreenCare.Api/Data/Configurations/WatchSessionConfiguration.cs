using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class WatchSessionConfiguration : IEntityTypeConfiguration<WatchSession>
{
    public void Configure(EntityTypeBuilder<WatchSession> builder)
    {
        builder.ToTable("WatchSessions", "dbo", table =>
        {
            table.HasCheckConstraint("CK_WatchSessions_VideoId", "[VideoId] BETWEEN 1 AND 30");
            table.HasCheckConstraint("CK_WatchSessions_Duration", "[DurationSeconds] BETWEEN 10 AND 7200");
            table.HasCheckConstraint(
                "CK_WatchSessions_Watched",
                "[WatchedSeconds] >= 0 AND [WatchedSeconds] <= [DurationSeconds]");
            table.HasCheckConstraint(
                "CK_WatchSessions_LastPosition",
                "[LastPositionSeconds] >= 0 AND [LastPositionSeconds] <= [DurationSeconds]");
            table.HasCheckConstraint(
                "CK_WatchSessions_QualifiedAfterCreated",
                "[QualifiedAtUtc] IS NULL OR [QualifiedAtUtc] >= [CreatedAtUtc]");
        });
        builder.HasKey(x => x.Id).HasName("PK_WatchSessions");

        builder.Property(x => x.Id).HasColumnType("uniqueidentifier").ValueGeneratedNever();
        builder.Property(x => x.DeviceId).HasColumnType("uniqueidentifier");
        builder.Property(x => x.VideoId).HasColumnType("tinyint");
        builder.Property(x => x.DurationSeconds).HasColumnType("decimal(10,3)");
        builder.Property(x => x.WatchedSeconds).HasColumnType("decimal(10,3)").HasDefaultValue(0m);
        builder.Property(x => x.LastPositionSeconds).HasColumnType("decimal(10,3)").HasDefaultValue(0m);
        builder.Property(x => x.LastPingAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.QualifiedAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Device)
            .WithMany(x => x.WatchSessions)
            .HasForeignKey(x => x.DeviceId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_WatchSessions_Devices_DeviceId");
        builder.HasOne(x => x.Video)
            .WithMany(x => x.WatchSessions)
            .HasForeignKey(x => x.VideoId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_WatchSessions_Videos_VideoId");

        builder.HasIndex(x => new { x.DeviceId, x.VideoId }, "IX_WatchSessions_Device_Video")
            .IncludeProperties(x => new
            {
                x.QualifiedAtUtc,
                x.WatchedSeconds,
                x.DurationSeconds,
                x.LastPingAtUtc
            });
    }
}
