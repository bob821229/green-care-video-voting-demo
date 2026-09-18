public sealed class ActivityOptions
{
    public const string SectionName = "Activity";

    public DateTimeOffset StartsAt { get; init; }

    public DateTimeOffset EndsAt { get; init; }
}
