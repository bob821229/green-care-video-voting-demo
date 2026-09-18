using GreenCare.Api.Infrastructure;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace GreenCare.Api.Tests.Infrastructure;

public sealed class DeviceSecurityTests
{
    private const string Secret = "unit-test-secret-with-at-least-32-characters";

    [Fact]
    public void Device_token_survives_service_restart_and_rejects_tampering()
    {
        var deviceId = Guid.NewGuid();
        var first = CreateTokenService();
        var token = first.Create(deviceId);
        var restarted = CreateTokenService();

        Assert.True(restarted.TryRead(token, out var restored));
        Assert.Equal(deviceId, restored);

        var tampered = $"{Guid.NewGuid():D}.{token[(token.IndexOf('.') + 1)..]}";
        Assert.False(restarted.TryRead(tampered, out _));
    }

    [Fact]
    public void Production_cookie_matches_security_baseline()
    {
        var context = new DefaultHttpContext();
        var service = new DeviceCookieService(
            CreateTokenService(),
            Options.Create(new SecurityOptions { AppSecret = Secret, DeviceCookieName = "vote_device" }),
            new TestHostEnvironment("Production"));

        var deviceId = service.GetOrCreate(context);
        var setCookie = context.Response.Headers.SetCookie.ToString();

        Assert.NotEqual(Guid.Empty, deviceId);
        Assert.Contains("vote_device=", setCookie);
        Assert.Contains("max-age=31536000", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("path=/", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("httponly", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("secure", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("samesite=lax", setCookie, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Persisted_data_protection_keys_can_be_used_after_restart()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"greencare-dp-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directory);
        try
        {
            var first = DataProtectionProvider.Create(new DirectoryInfo(directory), options =>
                options.SetApplicationName("GreenCare"));
            var protectedValue = first.CreateProtector("restart-test").Protect("device-value");

            var restarted = DataProtectionProvider.Create(new DirectoryInfo(directory), options =>
                options.SetApplicationName("GreenCare"));
            Assert.Equal("device-value", restarted.CreateProtector("restart-test").Unprotect(protectedValue));
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    private static DeviceTokenService CreateTokenService() =>
        new(new HmacService(Options.Create(new SecurityOptions { AppSecret = Secret })));

    private sealed class TestHostEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "GreenCare.Api.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
