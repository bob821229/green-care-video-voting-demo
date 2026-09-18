using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace GreenCare.Api.Infrastructure;

public interface IHmacService
{
    byte[] Compute(string purpose, string value);
    string ComputeHex(string purpose, string value);
    bool Verify(string purpose, string value, ReadOnlySpan<byte> expected);
}

public sealed class HmacService(IOptions<SecurityOptions> options) : IHmacService
{
    private readonly byte[] _key = Encoding.UTF8.GetBytes(options.Value.AppSecret);

    public byte[] Compute(string purpose, string value)
    {
        using var hmac = new HMACSHA256(_key);
        return hmac.ComputeHash(Encoding.UTF8.GetBytes($"{purpose}\n{value}"));
    }

    public string ComputeHex(string purpose, string value) =>
        Convert.ToHexString(Compute(purpose, value)).ToLowerInvariant();

    public bool Verify(string purpose, string value, ReadOnlySpan<byte> expected) =>
        CryptographicOperations.FixedTimeEquals(Compute(purpose, value), expected);
}
