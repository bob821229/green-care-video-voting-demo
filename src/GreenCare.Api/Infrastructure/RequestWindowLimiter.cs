using System.Collections.Concurrent;

namespace GreenCare.Api.Infrastructure;

public interface IRequestWindowLimiter
{
    bool Allow(string purpose, string key, int limit);
}

public sealed class RequestWindowLimiter(TimeProvider timeProvider, IHmacService hmac) : IRequestWindowLimiter
{
    private readonly ConcurrentDictionary<string, Queue<long>> _windows = new();

    public bool Allow(string purpose, string key, int limit)
    {
        var partition = hmac.ComputeHex($"request-window-{purpose}", key);
        var queue = _windows.GetOrAdd(partition, _ => new Queue<long>());
        var now = timeProvider.GetUtcNow().ToUnixTimeMilliseconds();
        lock (queue)
        {
            while (queue.Count > 0 && now - queue.Peek() >= 60_000) queue.Dequeue();
            if (queue.Count >= limit) return false;
            queue.Enqueue(now);
            return true;
        }
    }
}
