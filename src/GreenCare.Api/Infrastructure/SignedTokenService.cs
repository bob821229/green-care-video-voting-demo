namespace GreenCare.Api.Infrastructure;

public interface ISignedTokenService
{
    string Create(string purpose, Guid value);
    bool TryRead(string purpose, string? token, out Guid value);
}

public sealed class SignedTokenService(IHmacService hmac) : ISignedTokenService
{
    public string Create(string purpose, Guid value)
    {
        var text = value.ToString("D");
        return $"{text}.{hmac.ComputeHex(purpose, text)}";
    }

    public bool TryRead(string purpose, string? token, out Guid value)
    {
        value = Guid.Empty;
        if (string.IsNullOrWhiteSpace(token)) return false;
        var separator = token.LastIndexOf('.');
        if (separator <= 0 || !Guid.TryParseExact(token[..separator], "D", out value)) return false;
        try
        {
            var signature = Convert.FromHexString(token[(separator + 1)..]);
            if (signature.Length == 32 && hmac.Verify(purpose, token[..separator], signature)) return true;
        }
        catch (FormatException) { }
        value = Guid.Empty;
        return false;
    }
}
