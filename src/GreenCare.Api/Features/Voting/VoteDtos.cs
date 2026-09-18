namespace GreenCare.Api.Features.Voting;

public sealed record CreateVoteRequest(int VideoId, string? RecaptchaToken, string? DeviceSignal);
