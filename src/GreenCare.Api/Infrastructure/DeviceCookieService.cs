using Microsoft.Extensions.Options;

namespace GreenCare.Api.Infrastructure;

public interface IDeviceCookieService
{
    DeviceCookieResult GetOrCreate(HttpContext context);
}

public enum DeviceCookieStatus
{
    Valid,
    Missing,
    Invalid
}

public sealed record DeviceCookieResult(Guid DeviceId, DeviceCookieStatus Status);

public sealed class DeviceCookieService(
    IDeviceTokenService tokens,
    IOptions<SecurityOptions> options,
    IHostEnvironment environment) : IDeviceCookieService
{
    public DeviceCookieResult GetOrCreate(HttpContext context)
    {
        var name = options.Value.DeviceCookieName;
        var cookie = context.Request.Cookies[name];
        if (tokens.TryRead(cookie, out var existing))
            return new DeviceCookieResult(existing, DeviceCookieStatus.Valid);

        var deviceId = Guid.NewGuid();
        context.Response.Cookies.Append(name, tokens.Create(deviceId), new CookieOptions
        {
            HttpOnly = true,
            Secure = environment.IsProduction(),
            SameSite = SameSiteMode.Lax,
            Path = "/",
            MaxAge = TimeSpan.FromDays(365),
            IsEssential = true
        });
        var status = string.IsNullOrWhiteSpace(cookie)
            ? DeviceCookieStatus.Missing
            : DeviceCookieStatus.Invalid;
        return new DeviceCookieResult(deviceId, status);
    }
}
