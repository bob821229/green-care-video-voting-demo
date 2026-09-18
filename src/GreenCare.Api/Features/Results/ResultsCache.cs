namespace GreenCare.Api.Features.ResultData;

public interface IResultsCache
{
    Task<ResultsPayload> GetOrCreateAsync(Func<Task<ResultsPayload>> factory, CancellationToken cancellationToken);
    void Invalidate();
}

public sealed class ResultsCache(TimeProvider timeProvider) : IResultsCache
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private ResultsPayload? _payload;
    private DateTimeOffset _expiresAt;
    private long _generation;

    public async Task<ResultsPayload> GetOrCreateAsync(Func<Task<ResultsPayload>> factory, CancellationToken cancellationToken)
    {
        if (_payload is not null && timeProvider.GetUtcNow() < _expiresAt) return _payload;
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_payload is not null && timeProvider.GetUtcNow() < _expiresAt) return _payload;
            var generation = _generation;
            var payload = await factory();
            if (generation == _generation)
            {
                _payload = payload;
                _expiresAt = timeProvider.GetUtcNow().AddSeconds(5);
            }
            return payload;
        }
        finally
        {
            _gate.Release();
        }
    }

    public void Invalidate()
    {
        Interlocked.Increment(ref _generation);
        _payload = null;
        _expiresAt = default;
    }
}
