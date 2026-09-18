using GreenCare.Api.Features.Voting;

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
}
