using GreenCare.Api.Data;
using GreenCare.Api.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GreenCare.Api.Features.Voting;

public sealed record VoteRisk(byte[] IpHash, byte[]? DeviceSignalHash, byte Score, string Status, int RecentIp, int OtherDevices);

public interface IVoteRiskService
{
    Task<VoteRisk> EvaluateAsync(Guid deviceId, string? remoteIp, string? deviceSignal, DateTime nowUtc, CancellationToken cancellationToken);
}

public sealed class VoteRiskService(GreenCareDbContext db, IVoteEnvironmentService environments) : IVoteRiskService
{
    public async Task<VoteRisk> EvaluateAsync(Guid deviceId, string? remoteIp, string? deviceSignal, DateTime nowUtc, CancellationToken cancellationToken)
    {
        var environment = environments.Create(remoteIp, deviceSignal);
        var ipHash = environment.IpHash;
        var signalHash = environment.DeviceSignalHash;
        var cutoff = nowUtc.AddMinutes(-10);
        var recentIp = await db.Votes.CountAsync(x => x.IpHash == ipHash && x.CreatedAtUtc >= cutoff, cancellationToken);
        var others = signalHash is null ? 0 : await db.Votes
            .Where(x => x.DeviceSignalHash == signalHash && x.DeviceId != deviceId)
            .Select(x => x.DeviceId)
            .Distinct()
            .CountAsync(cancellationToken);
        var score = VoteRiskCalculator.Calculate(recentIp, others);
        return new VoteRisk(ipHash, signalHash, (byte)score, score >= 60 ? "flagged" : "valid", recentIp, others);
    }
}

public static class VoteRiskCalculator
{
    public static int Calculate(int recentIp, int otherDevices) =>
        Math.Clamp((recentIp - 20) * 4 + otherDevices * 25, 0, 100);
}
