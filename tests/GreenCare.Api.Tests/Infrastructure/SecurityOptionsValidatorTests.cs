using GreenCare.Api.Infrastructure;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace GreenCare.Api.Tests.Infrastructure;

public sealed class SecurityOptionsValidatorTests
{
    [Fact]
    public void Production_rejects_missing_or_development_secret()
    {
        var validator = new SecurityOptionsValidator(new TestHostEnvironment("Production"));

        var result = validator.Validate(null, new SecurityOptions
        {
            AppSecret = "development-only-secret-change-before-deploy-2026",
            DataProtectionKeysPath = "keys"
        });

        Assert.True(result.Failed);
    }

    private sealed class TestHostEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "GreenCare.Api.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
