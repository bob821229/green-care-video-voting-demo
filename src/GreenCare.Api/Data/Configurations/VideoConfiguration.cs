using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class VideoConfiguration : IEntityTypeConfiguration<Video>
{
    public void Configure(EntityTypeBuilder<Video> builder)
    {
        builder.ToTable("Videos", "dbo", table =>
        {
            table.HasCheckConstraint(
                "CK_Videos_Number",
                "[Number] = RIGHT('0' + CONVERT(varchar(2), [Id]), 2)");
            table.HasCheckConstraint("CK_Videos_Category", "[Category] IN ('individual', 'team')");
            table.HasCheckConstraint("CK_Videos_SortOrder", "[SortOrder] >= 1");
            table.HasCheckConstraint("CK_Videos_Title", "NULLIF(LTRIM(RTRIM([Title])), N'') IS NOT NULL");
            table.HasCheckConstraint("CK_Videos_Team", "NULLIF(LTRIM(RTRIM([Team])), N'') IS NOT NULL");
            table.HasCheckConstraint("CK_Videos_YoutubeId", "NULLIF(LTRIM(RTRIM([YoutubeId])), '') IS NOT NULL");
            table.HasCheckConstraint("CK_Videos_Poster", "NULLIF(LTRIM(RTRIM([Poster])), N'') IS NOT NULL");
            table.HasCheckConstraint("CK_Videos_UpdatedAfterCreated", "[UpdatedAtUtc] >= [CreatedAtUtc]");
        });

        builder.HasKey(x => x.Id).HasName("PK_Videos");
        builder.HasAlternateKey(x => x.Number).HasName("UQ_Videos_Number");
        builder.HasAlternateKey(x => new { x.Category, x.SortOrder })
            .HasName("UQ_Videos_Category_SortOrder");

        builder.Property(x => x.Id).HasColumnType("tinyint").ValueGeneratedNever();
        builder.Property(x => x.Number).HasColumnType("char(2)").IsFixedLength().HasMaxLength(2);
        builder.Property(x => x.Title).HasColumnType("nvarchar(200)").HasMaxLength(200);
        builder.Property(x => x.Team).HasColumnType("nvarchar(200)").HasMaxLength(200);
        builder.Property(x => x.YoutubeId).HasColumnType("varchar(32)").HasMaxLength(32);
        builder.Property(x => x.Poster).HasColumnType("nvarchar(500)").HasMaxLength(500);
        builder.Property(x => x.Category).HasColumnType("varchar(10)").HasMaxLength(10);
        builder.Property(x => x.SortOrder).HasColumnType("tinyint");
        builder.Property(x => x.IsActive).HasColumnType("bit").HasDefaultValue(true);
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)").HasDefaultValueSql("SYSUTCDATETIME()");
        builder.Property(x => x.UpdatedAtUtc).HasColumnType("datetime2(3)").HasDefaultValueSql("SYSUTCDATETIME()");
    }
}
