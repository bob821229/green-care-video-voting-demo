using System.Collections.Concurrent;
using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Devices;

public interface IDeviceIdentityService
{
    Task<Guid> GetOrCreateAsync(HttpContext context, CancellationToken cancellationToken);
}

public sealed class DeviceIdentityService(
    IDeviceCookieService cookies,
    GreenCareDbContext db,
    TimeProvider timeProvider) : IDeviceIdentityService
{
    private static readonly ConcurrentDictionary<Guid, DateTimeOffset> LastTouches = new();

    public async Task<Guid> GetOrCreateAsync(HttpContext context, CancellationToken cancellationToken)
    {
        var id = cookies.GetOrCreate(context);
        var now = timeProvider.GetUtcNow();
        if (LastTouches.TryGetValue(id, out var last) && now - last < TimeSpan.FromMinutes(5)) return id;

        var device = await db.Devices.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
        if (device is null)
        {
            db.Devices.Add(new Device { Id = id, CreatedAtUtc = now.UtcDateTime, LastSeenAtUtc = now.UtcDateTime });
        }
        else
        {
            device.LastSeenAtUtc = now.UtcDateTime;
        }
        await db.SaveChangesAsync(cancellationToken);
        LastTouches[id] = now;
        return id;
    }
}
