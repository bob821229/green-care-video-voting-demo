using GreenCare.Api.Data;
using GreenCare.Api.Infrastructure;
using GreenCare.Api.Features;
using GreenCare.Api.Features.Voting;
using GreenCare.Api.Features.ResultData;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddGreenCareDataAccess(builder.Configuration);
builder.Services.AddGreenCareInfrastructure(builder.Configuration, builder.Environment);

builder.Services
    .AddOptions<ActivityOptions>()
    .Bind(builder.Configuration.GetSection(ActivityOptions.SectionName))
    .Validate(options => options.StartsAt != default, "Activity start time is required.")
    .Validate(options => options.EndsAt > options.StartsAt, "Activity end time must be later than its start time.")
    .ValidateOnStart();

var app = builder.Build();

app.UseForwardedHeaders();
app.UseMiddleware<ApiExceptionMiddleware>();
app.UseMiddleware<SecurityHeadersMiddleware>();
if (app.Environment.IsProduction()) app.UseHsts();
app.UseRateLimiter();
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/api/health", (IHostEnvironment environment, IActivityService activityService) =>
{
    var activity = activityService.GetStatus();
    return
    Results.Ok(new
    {
        status = "ok",
        environment = environment.EnvironmentName,
        activity = new
        {
            state = activity.State.ToString().ToLowerInvariant(),
            startsAt = activity.StartsAt,
            endsAt = activity.EndsAt
        }
    });
}).RequireRateLimiting(RateLimitPolicies.GeneralIp);

app.MapGreenCarePublicApi();
app.MapGreenCareVotingApi();
app.MapGreenCareResultsApi();

app.MapGet("/results.html", () => Results.Redirect("/results"));
app.MapFallbackToFile("index.html");

app.Run();

public partial class Program;
