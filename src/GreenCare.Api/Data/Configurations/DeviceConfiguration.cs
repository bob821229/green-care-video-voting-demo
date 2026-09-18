using GreenCare.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GreenCare.Api.Data.Configurations;

public sealed class DeviceConfiguration : IEntityTypeConfiguration<Device>
{
    public void Configure(EntityTypeBuilder<Device> builder)
    {
        builder.ToTable("Devices", "dbo", table =>
            table.HasCheckConstraint(
                "CK_Devices_LastSeenAfterCreated",
                "[LastSeenAtUtc] >= [CreatedAtUtc]"));
        builder.HasKey(x => x.Id).HasName("PK_Devices");

        builder.Property(x => x.Id).HasColumnType("uniqueidentifier").ValueGeneratedNever();
        builder.Property(x => x.CreatedAtUtc).HasColumnType("datetime2(3)");
        builder.Property(x => x.LastSeenAtUtc).HasColumnType("datetime2(3)");
    }
}
