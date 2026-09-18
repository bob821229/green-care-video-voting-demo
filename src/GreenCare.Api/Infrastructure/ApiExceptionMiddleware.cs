using System.Text.Json;

namespace GreenCare.Api.Infrastructure;

public sealed class ApiExceptionMiddleware(RequestDelegate next, ILogger<ApiExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Unhandled request failure. TraceId={TraceId} ExceptionType={ExceptionType}",
                context.TraceIdentifier,
                exception.GetType().FullName);

            if (context.Response.HasStarted) throw;
            context.Response.Clear();
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/json; charset=utf-8";
            await JsonSerializer.SerializeAsync(
                context.Response.Body,
                new { error = "伺服器暫時無法處理請求，請稍後再試。" },
                cancellationToken: context.RequestAborted);
        }
    }
}
