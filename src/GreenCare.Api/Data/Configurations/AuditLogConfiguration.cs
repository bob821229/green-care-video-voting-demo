using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> builder)
    {
        builder.ToTable("AuditLogs", "dbo", table =>
            table.HasCheckConstraint(
                "CK_AuditLogs_DetailJson",
                "[DetailJson] IS NULL OR ISJSON([DetailJson]) = 1"));
        builder.HasKey(x => x.Id).HasName("PK_AuditLogs");

        builder.Property(x => x.Id).HasColumnType("bigint").UseIdentityColumn();
        builder.Property(x => x.Action).HasColumnType("varchar(50)").IsRequired();
        builder.Property(x => x.Target).HasColumnType("nvarchar(200)").IsRequired();
        builder.Property(x => x.DetailJson).HasColumnType("nvarchar(max)");
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)");

        builder.HasIndex(x => new { x.Action, x.CreatedAtUtc }, "IX_AuditLogs_Action_CreatedAtUtc");
    }
}
