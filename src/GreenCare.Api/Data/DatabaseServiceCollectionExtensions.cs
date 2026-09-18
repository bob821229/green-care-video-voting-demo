using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Data;

public static class DatabaseServiceCollectionExtensions
{
    public const string ConnectionStringName = "GreenCare";

    public static IServiceCollection AddGreenCareDataAccess(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString(ConnectionStringName);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                $"Connection string '{ConnectionStringName}' is required. " +
                $"Set ConnectionStrings__{ConnectionStringName} in the host environment.");
        }

        services.AddDbContext<GreenCareDbContext>(options => options.UseSqlServer(connectionString));
        return services;
    }
}
