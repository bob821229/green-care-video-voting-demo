using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace GreenCare.Api.Features.Voting;

public interface ICaptchaVerifier
{
    Task<bool> VerifyAsync(string? token, string? remoteIp, CancellationToken cancellationToken);
}

public sealed class CaptchaVerifier(
    HttpClient client,
    IOptions<CaptchaOptions> options,
    IHostEnvironment environment) : ICaptchaVerifier
{
    public async Task<bool> VerifyAsync(string? token, string? remoteIp, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.SecretKey))
            return !environment.IsProduction() && token == "development-pass";
        if (string.IsNullOrWhiteSpace(token)) return false;

        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["secret"] = options.Value.SecretKey,
            ["response"] = token,
            ["remoteip"] = remoteIp ?? string.Empty
        });
        try
        {
            using var response = await client.PostAsync("recaptcha/api/siteverify", content, cancellationToken);
            if (!response.IsSuccessStatusCode) return false;
            var result = await response.Content.ReadFromJsonAsync<CaptchaResponse>(cancellationToken);
            return result?.Success == true &&
                   (string.IsNullOrWhiteSpace(options.Value.ExpectedHostname) ||
                    string.Equals(result.Hostname, options.Value.ExpectedHostname, StringComparison.OrdinalIgnoreCase) ||
                    (!environment.IsProduction() && string.Equals(result.Hostname, "localhost", StringComparison.OrdinalIgnoreCase)));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return false;
        }
        catch (HttpRequestException)
        {
            return false;
        }
    }

    private sealed record CaptchaResponse(
        [property: JsonPropertyName("success")] bool Success,
        [property: JsonPropertyName("hostname")] string? Hostname);
}
