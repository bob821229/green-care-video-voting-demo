namespace GreenCare.Api.Infrastructure;

public sealed class SecurityHeadersMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var headers = context.Response.Headers;
        headers.XContentTypeOptions = "nosniff";
        headers.XFrameOptions = "DENY";
        headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
        headers.Append("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
        headers.Append(
            "Content-Security-Policy",
            "default-src 'self'; img-src 'self' data: https://i.ytimg.com; " +
            "frame-src https://www.youtube.com https://www.youtube-nocookie.com https://www.google.com; " +
            "script-src 'self' https://www.youtube.com https://www.google.com https://www.gstatic.com; " +
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
            "font-src 'self' data: https://fonts.gstatic.com; " +
            "connect-src 'self' https://www.google.com; object-src 'none'; base-uri 'self'");
        await next(context);
    }
}
