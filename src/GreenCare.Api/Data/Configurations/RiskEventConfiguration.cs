using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class RiskEventConfiguration : IEntityTypeConfiguration<RiskEvent>
{
    public void Configure(EntityTypeBuilder<RiskEvent> builder)
    {
        builder.ToTable("RiskEvents", "dbo", table =>
            table.HasCheckConstraint(
                "CK_RiskEvents_DetailJson",
                "[DetailJson] IS NULL OR ISJSON([DetailJson]) = 1"));
        builder.HasKey(x => x.Id).HasName("PK_RiskEvents");

        builder.Property(x => x.Id).HasColumnType("bigint").UseIdentityColumn();
        builder.Property(x => x.DeviceId).HasColumnType("uniqueidentifier");
        builder.Property(x => x.IpHash).HasColumnType("binary(32)").IsFixedLength().HasMaxLength(32);
        builder.Property(x => x.Kind).HasColumnType("varchar(50)").IsRequired();
        builder.Property(x => x.DetailJson).HasColumnType("nvarchar(max)");
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Device)
            .WithMany(x => x.RiskEvents)
            .HasForeignKey(x => x.DeviceId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_RiskEvents_Devices_DeviceId");

        builder.HasIndex(x => new { x.DeviceId, x.CreatedAtUtc }, "IX_RiskEvents_Device_CreatedAtUtc");
        builder.HasIndex(x => new { x.IpHash, x.CreatedAtUtc }, "IX_RiskEvents_IpHash_CreatedAtUtc");
    }
}
