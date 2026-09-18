using System.Text;
using System.Text.Json;
using GreenCare.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;

namespace GreenCare.Api.Tests.Infrastructure;

public sealed class MiddlewareTests
{
    [Fact]
    public async Task Api_exception_response_does_not_expose_exception_or_secret()
    {
        const string secret = "sql-password-should-never-leak";
        var middleware = new ApiExceptionMiddleware(
            _ => throw new InvalidOperationException(secret),
            NullLogger<ApiExceptionMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);
        context.Response.Body.Position = 0;
        var body = await new StreamReader(context.Response.Body, Encoding.UTF8).ReadToEndAsync();

        Assert.Equal(StatusCodes.Status500InternalServerError, context.Response.StatusCode);
        using var json = JsonDocument.Parse(body);
        Assert.Contains("伺服器暫時無法處理請求", json.RootElement.GetProperty("error").GetString());
        Assert.DoesNotContain(secret, body);
        Assert.DoesNotContain(nameof(InvalidOperationException), body);
    }

    [Fact]
    public async Task Security_headers_are_added_to_every_response()
    {
        var middleware = new SecurityHeadersMiddleware(_ => Task.CompletedTask);
        var context = new DefaultHttpContext();

        await middleware.InvokeAsync(context);

        Assert.Equal("nosniff", context.Response.Headers.XContentTypeOptions);
        Assert.Equal("DENY", context.Response.Headers.XFrameOptions);
        Assert.Contains("object-src 'none'", context.Response.Headers.ContentSecurityPolicy.ToString());
        Assert.Equal("strict-origin-when-cross-origin", context.Response.Headers["Referrer-Policy"]);
    }
}
