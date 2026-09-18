using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class SchemaVersionConfiguration : IEntityTypeConfiguration<SchemaVersion>
{
    public void Configure(EntityTypeBuilder<SchemaVersion> builder)
    {
        builder.ToTable("SchemaVersions", "dbo");
        builder.HasKey(x => x.VersionNumber).HasName("PK_SchemaVersions");

        builder.Property(x => x.VersionNumber).HasColumnType("varchar(20)").ValueGeneratedNever();
        builder.Property(x => x.Description).HasColumnType("nvarchar(200)").IsRequired();
        builder.Property(x => x.AppliedAtUtc)
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .ValueGeneratedOnAdd();
        builder.Property(x => x.AppliedBy)
            .HasColumnType("sysname")
            .HasDefaultValueSql("ORIGINAL_LOGIN()")
            .ValueGeneratedOnAdd();
    }
}
