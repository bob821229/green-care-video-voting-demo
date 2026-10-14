using System.Collections.Concurrent;
using System.Text.Json;
using GreenCare.Api.Data;
using GreenCare.Api.Data.Entities;
using GreenCare.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Devices;

public interface IDeviceIdentityService
{
    Task<Guid> GetOrCreateAsync(HttpContext context, CancellationToken cancellationToken);
    Task<DeviceIdentity> GetOrCreateDetailedAsync(HttpContext context, CancellationToken cancellationToken);
}

public sealed record DeviceIdentity(Guid DeviceId, DeviceCookieStatus CookieStatus);

public sealed class DeviceIdentityService(
    IDeviceCookieService cookies,
    GreenCareDbContext db,
    TimeProvider timeProvider) : IDeviceIdentityService
{
    private static readonly ConcurrentDictionary<Guid, DateTimeOffset> LastTouches = new();

    public async Task<Guid> GetOrCreateAsync(HttpContext context, CancellationToken cancellationToken)
        => (await GetOrCreateDetailedAsync(context, cancellationToken)).DeviceId;

    public async Task<DeviceIdentity> GetOrCreateDetailedAsync(HttpContext context, CancellationToken cancellationToken)
    {
        var cookie = cookies.GetOrCreate(context);
        var id = cookie.DeviceId;
        var now = timeProvider.GetUtcNow();
        if (LastTouches.TryGetValue(id, out var last) && now - last < TimeSpan.FromMinutes(5))
            return new DeviceIdentity(id, cookie.Status);

        var device = await db.Devices.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
        if (device is null)
        {
            db.Devices.Add(new Device { Id = id, CreatedAtUtc = now.UtcDateTime, LastSeenAtUtc = now.UtcDateTime });
        }
        else
        {
            device.LastSeenAtUtc = now.UtcDateTime;
        }
        if (cookie.Status == DeviceCookieStatus.Invalid)
        {
            db.RiskEvents.Add(new RiskEvent
            {
                DeviceId = id,
                Kind = "device_cookie_invalid",
                DetailJson = JsonSerializer.Serialize(new { reissued = true }),
                CreatedAtUtc = now.UtcDateTime
            });
        }
        await db.SaveChangesAsync(cancellationToken);
        LastTouches[id] = now;
        return new DeviceIdentity(id, cookie.Status);
    }
}
