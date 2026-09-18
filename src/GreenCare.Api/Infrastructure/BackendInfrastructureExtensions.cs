using System.Net;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using GreenCare.Api.Features.Devices;
using GreenCare.Api.Features.Videos;
using GreenCare.Api.Features.Voting;
using GreenCare.Api.Features.ResultData;

namespace GreenCare.Api.Infrastructure;

public static class BackendInfrastructureExtensions
{
    public static IServiceCollection AddGreenCareInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddSingleton<IValidateOptions<SecurityOptions>, SecurityOptionsValidator>();
        services.AddOptions<SecurityOptions>()
            .Bind(configuration.GetSection(SecurityOptions.SectionName))
            .ValidateOnStart();

        var security = configuration.GetSection(SecurityOptions.SectionName).Get<SecurityOptions>()
            ?? new SecurityOptions();
        var keysPath = Path.GetFullPath(
            string.IsNullOrWhiteSpace(security.DataProtectionKeysPath) ? ".invalid-keys-path" : security.DataProtectionKeysPath,
            environment.ContentRootPath);
        var dataProtection = services.AddDataProtection()
            .PersistKeysToFileSystem(new DirectoryInfo(keysPath))
            .SetApplicationName("GreenCare");
        if (environment.IsProduction() && OperatingSystem.IsWindows())
        {
            dataProtection.ProtectKeysWithDpapi(protectToLocalMachine: true);
        }

        var forwarded = configuration.GetSection(ForwardedHeadersSettings.SectionName)
            .Get<ForwardedHeadersSettings>() ?? new ForwardedHeadersSettings();
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.ForwardLimit = forwarded.ForwardLimit;
            options.KnownNetworks.Clear();
            options.KnownProxies.Clear();
            foreach (var value in forwarded.KnownProxies)
            {
                if (!IPAddress.TryParse(value, out var address))
                {
                    throw new InvalidOperationException($"Invalid ForwardedHeaders:KnownProxies address '{value}'.");
                }
                options.KnownProxies.Add(address);
            }
        });

        services.Configure<Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServerOptions>(options =>
        {
            options.AddServerHeader = false;
            options.Limits.MaxRequestBodySize = 20 * 1024;
        });
        services.Configure<IISServerOptions>(options => options.MaxRequestBodySize = 20 * 1024);

        services.AddSingleton<TimeProvider, SystemTimeProvider>();
        services.AddSingleton<IActivityService, ActivityService>();
        services.AddSingleton<IHmacService, HmacService>();
        services.AddSingleton<IDeviceTokenService, DeviceTokenService>();
        services.AddSingleton<ISignedTokenService, SignedTokenService>();
        services.AddSingleton<IRequestWindowLimiter, RequestWindowLimiter>();
        services.AddSingleton<IResultsCache, ResultsCache>();
        services.AddSingleton<IVideoCatalog, VideoCatalog>();
        services.AddScoped<IDeviceCookieService, DeviceCookieService>();
        services.AddScoped<IDeviceIdentityService, DeviceIdentityService>();
        services.AddScoped<IVoteRiskService, VoteRiskService>();
        services.AddHttpClient<ICaptchaVerifier, CaptchaVerifier>(client =>
        {
            client.BaseAddress = new Uri("https://www.google.com/");
            client.Timeout = TimeSpan.FromSeconds(8);
        });
        services.AddOptions<CaptchaOptions>()
            .Bind(configuration.GetSection(CaptchaOptions.SectionName))
            .Validate(options => !environment.IsProduction() ||
                                 (!string.IsNullOrWhiteSpace(options.SiteKey) &&
                                  !string.IsNullOrWhiteSpace(options.SecretKey) &&
                                  !string.IsNullOrWhiteSpace(options.ExpectedHostname)),
                "Production requires Captcha SiteKey, SecretKey, and ExpectedHostname.")
            .ValidateOnStart();

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, cancellationToken) =>
            {
                context.HttpContext.Response.Headers.RetryAfter = "60";
                await context.HttpContext.Response.WriteAsJsonAsync(
                    new { error = "操作過於頻繁，請稍後再試。" },
                    cancellationToken);
            };
            AddIpPolicy(options, RateLimitPolicies.GeneralIp, 600);
            AddIpPolicy(options, RateLimitPolicies.WatchStartIp, 120);
            AddIpPolicy(options, RateLimitPolicies.WatchProgressIp, 600);
            AddIpPolicy(options, RateLimitPolicies.VoteIp, 30);
        });

        return services;
    }

    private static void AddIpPolicy(RateLimiterOptions options, string name, int permitLimit)
    {
        options.AddPolicy(name, context =>
        {
            var address = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            var partition = context.RequestServices.GetRequiredService<IHmacService>()
                .ComputeHex("rate-limit-ip-v1", address);
            return RateLimitPartition.GetFixedWindowLimiter(partition, _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = permitLimit,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            });
        });
    }
}
