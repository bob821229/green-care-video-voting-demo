using GreenCare.Api.Infrastructure;

namespace GreenCare.Api.Features.Voting;

public sealed record VoteEnvironment(byte[] IpHash, byte[]? DeviceSignalHash);

public interface IVoteEnvironmentService
{
    VoteEnvironment Create(string? remoteIp, string? deviceSignal);
}

public sealed class VoteEnvironmentService(IHmacService hmac) : IVoteEnvironmentService
{
    public VoteEnvironment Create(string? remoteIp, string? deviceSignal) => new(
        hmac.Compute("vote-ip-v1", remoteIp ?? string.Empty),
        string.IsNullOrWhiteSpace(deviceSignal)
            ? null
            : hmac.Compute("device-signal-v1", deviceSignal));
}
