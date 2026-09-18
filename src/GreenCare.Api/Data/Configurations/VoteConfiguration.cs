using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class VoteConfiguration : IEntityTypeConfiguration<Vote>
{
    public void Configure(EntityTypeBuilder<Vote> builder)
    {
        builder.ToTable("Votes", "dbo", table =>
        {
            table.HasCheckConstraint("CK_Votes_VideoId", "[VideoId] BETWEEN 1 AND 30");
            table.HasCheckConstraint("CK_Votes_Category", "[Category] IN ('individual', 'team')");
            table.HasCheckConstraint(
                "CK_Votes_VideoCategory",
                "([VideoId] BETWEEN 1 AND 15 AND [Category] = 'individual') OR " +
                "([VideoId] BETWEEN 16 AND 30 AND [Category] = 'team')");
            table.HasCheckConstraint("CK_Votes_RiskScore", "[RiskScore] BETWEEN 0 AND 100");
            table.HasCheckConstraint(
                "CK_Votes_Status",
                "[Status] IN ('valid', 'flagged', 'cancelled', 'void')");
            table.HasCheckConstraint(
                "CK_Votes_CancelledState",
                "([Status] = 'cancelled' AND [CancelledAtUtc] IS NOT NULL) OR " +
                "([Status] <> 'cancelled' AND [CancelledAtUtc] IS NULL)");
            table.HasCheckConstraint(
                "CK_Votes_VoidedState",
                "([Status] = 'void' AND [VoidedAtUtc] IS NOT NULL AND " +
                "NULLIF(LTRIM(RTRIM([VoidReason])), N'') IS NOT NULL) OR " +
                "([Status] <> 'void' AND [VoidedAtUtc] IS NULL AND [VoidReason] IS NULL)");
            table.HasCheckConstraint(
                "CK_Votes_ReplacedVoteState",
                "[ReplacedByVoteId] IS NULL OR ([Status] = 'cancelled' AND [ReplacedByVoteId] <> [Id])");
        });
        builder.HasKey(x => x.Id).HasName("PK_Votes");

        builder.Property(x => x.Id).HasColumnType("bigint").UseIdentityColumn();
        builder.Property(x => x.DeviceId).HasColumnType("uniqueidentifier");
        builder.Property(x => x.VideoId).HasColumnType("tinyint");
        builder.Property(x => x.Category).HasColumnType("varchar(10)").IsRequired();
        builder.Property(x => x.WatchSessionId).HasColumnType("uniqueidentifier");
        builder.Property(x => x.IpHash).HasColumnType("binary(32)").IsFixedLength().HasMaxLength(32);
        builder.Property(x => x.DeviceSignalHash).HasColumnType("binary(32)").IsFixedLength().HasMaxLength(32);
        builder.Property(x => x.RiskScore).HasColumnType("tinyint").HasDefaultValue((byte)0);
        builder.Property(x => x.Status).HasColumnType("varchar(10)").HasDefaultValue(VoteStatuses.Valid);
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.CancelledAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.ReplacedByVoteId).HasColumnType("bigint");
        builder.Property(x => x.VoidedAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.VoidReason).HasColumnType("nvarchar(300)");
        builder.Property(x => x.IsActive)
            .HasComputedColumnSql(
                "CASE WHEN [Status] IN ('valid', 'flagged') " +
                "THEN CONVERT(bit, (1)) ELSE CONVERT(bit, (0)) END",
                stored: true);

        builder.HasOne(x => x.Device)
            .WithMany(x => x.Votes)
            .HasForeignKey(x => x.DeviceId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Votes_Devices_DeviceId");
        builder.HasOne(x => x.WatchSession)
            .WithMany(x => x.Votes)
            .HasForeignKey(x => x.WatchSessionId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Votes_WatchSessions_WatchSessionId");
        builder.HasOne(x => x.ReplacedByVote)
            .WithMany(x => x.ReplacedVotes)
            .HasForeignKey(x => x.ReplacedByVoteId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Votes_Votes_ReplacedByVoteId");

        builder.HasIndex(x => new { x.DeviceId, x.VideoId }, "UX_Votes_Device_Video_Active")
            .IsUnique()
            .HasFilter("[CancelledAtUtc] IS NULL AND [VoidedAtUtc] IS NULL");
        builder.HasIndex(x => new { x.DeviceId, x.Category, x.Status }, "IX_Votes_Device_Category_Status")
            .IncludeProperties(x => new { x.VideoId, x.CreatedAtUtc });
        builder.HasIndex(x => new { x.VideoId, x.Status }, "IX_Votes_Video_Status")
            .IncludeProperties(x => x.CreatedAtUtc);
        builder.HasIndex(x => new { x.IpHash, x.CreatedAtUtc }, "IX_Votes_IpHash_CreatedAtUtc");
    }
}
