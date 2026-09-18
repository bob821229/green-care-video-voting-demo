namespace GreenCare.Api.Infrastructure;

public interface IDeviceTokenService
{
    string Create(Guid deviceId);
    bool TryRead(string? token, out Guid deviceId);
}

public sealed class DeviceTokenService(IHmacService hmacService) : IDeviceTokenService
{
    private const string Purpose = "device-cookie-v1";

    public string Create(Guid deviceId)
    {
        var id = deviceId.ToString("D");
        return $"{id}.{hmacService.ComputeHex(Purpose, id)}";
    }

    public bool TryRead(string? token, out Guid deviceId)
    {
        deviceId = Guid.Empty;
        if (string.IsNullOrWhiteSpace(token)) return false;

        var separator = token.IndexOf('.');
        if (separator <= 0 || separator != token.LastIndexOf('.')) return false;

        var idText = token[..separator];
        var signatureText = token[(separator + 1)..];
        if (!Guid.TryParseExact(idText, "D", out deviceId)) return false;

        try
        {
            var signature = Convert.FromHexString(signatureText);
            if (signature.Length == 32 && hmacService.Verify(Purpose, idText, signature)) return true;
        }
        catch (FormatException)
        {
            // Invalid external token; handled as an anonymous new device.
        }

        deviceId = Guid.Empty;
        return false;
    }
}
