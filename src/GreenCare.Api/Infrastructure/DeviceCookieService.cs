using Microsoft.Extensions.Options;

namespace GreenCare.Api.Infrastructure;

public interface IDeviceCookieService
{
    Guid GetOrCreate(HttpContext context);
}

public sealed class DeviceCookieService(
    IDeviceTokenService tokens,
    IOptions<SecurityOptions> options,
    IHostEnvironment environment) : IDeviceCookieService
{
    public Guid GetOrCreate(HttpContext context)
    {
        var name = options.Value.DeviceCookieName;
        if (tokens.TryRead(context.Request.Cookies[name], out var existing)) return existing;

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
        return deviceId;
    }
}
