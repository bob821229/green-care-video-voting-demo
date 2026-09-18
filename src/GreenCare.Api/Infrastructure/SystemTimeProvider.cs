namespace GreenCare.Api.Infrastructure;

public sealed class SystemTimeProvider : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => DateTimeOffset.UtcNow;
}
