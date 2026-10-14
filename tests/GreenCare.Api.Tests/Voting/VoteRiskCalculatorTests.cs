using GreenCare.Api.Features.Voting;
using GreenCare.Api.Data.Entities;

namespace GreenCare.Api.Tests.Voting;

public sealed class VoteRiskCalculatorTests
{
    [Theory]
    [InlineData(20, 0, 0)]
    [InlineData(21, 0, 4)]
    [InlineData(20, 2, 50)]
    [InlineData(30, 1, 65)]
    [InlineData(100, 10, 100)]
    public void Score_is_bounded_and_matches_existing_rules(int recentIp, int otherDevices, int expected)
    {
        Assert.Equal(expected, VoteRiskCalculator.Calculate(recentIp, otherDevices));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(60)]
    [InlineData(100)]
    public void Accepted_votes_remain_valid_while_risk_is_audit_only(int score)
    {
        Assert.Equal(VoteStatuses.Valid, VoteRiskCalculator.Status(score));
    }
}
