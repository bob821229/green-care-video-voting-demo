using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace GreenCare.Api.Tests.Infrastructure;

public sealed class ForwardedHeadersTests
{
    [Fact]
    public async Task Trusted_iis_proxy_can_forward_client_ip_and_scheme()
    {
        IPAddress? observedAddress = null;
        string? observedScheme = null;
        var options = CreateOptions();
        var middleware = new ForwardedHeadersMiddleware(
            context =>
            {
                observedAddress = context.Connection.RemoteIpAddress;
                observedScheme = context.Request.Scheme;
                return Task.CompletedTask;
            },
            NullLoggerFactory.Instance,
            Options.Create(options));
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Loopback;
        context.Request.Headers["X-Forwarded-For"] = "203.0.113.10";
        context.Request.Headers["X-Forwarded-Proto"] = "https";

        await middleware.Invoke(context);

        Assert.Equal(IPAddress.Parse("203.0.113.10"), observedAddress);
        Assert.Equal("https", observedScheme);
    }

    [Fact]
    public async Task Untrusted_proxy_headers_are_ignored()
    {
        IPAddress? observedAddress = null;
        var middleware = new ForwardedHeadersMiddleware(
            context =>
            {
                observedAddress = context.Connection.RemoteIpAddress;
                return Task.CompletedTask;
            },
            NullLoggerFactory.Instance,
            Options.Create(CreateOptions()));
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse("198.51.100.20");
        context.Request.Headers["X-Forwarded-For"] = "203.0.113.10";

        await middleware.Invoke(context);

        Assert.Equal(IPAddress.Parse("198.51.100.20"), observedAddress);
    }

    private static ForwardedHeadersOptions CreateOptions()
    {
        var options = new ForwardedHeadersOptions
        {
            ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
            ForwardLimit = 1
        };
        options.KnownNetworks.Clear();
        options.KnownProxies.Clear();
        options.KnownProxies.Add(IPAddress.Loopback);
        return options;
    }
}
