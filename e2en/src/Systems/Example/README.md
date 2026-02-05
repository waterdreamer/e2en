# Example System

Demonstrates core framework patterns: services, controllers, and client-server communication.

## Key Concepts

- **Service.Client table** > Exposed to clients (signals, properties, methods)
- **CreateSignal()** > RemoteEvent wrapper
- **CreateProperty(initial)** > Replicated state with per-player support
- **Client methods** > RemoteFunctions (player auto-injected on server)
- **Troves** > Automatic cleanup on player disconnect

See the inline comments in the code for detailed explanations.
