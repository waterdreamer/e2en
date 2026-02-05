This is a wrapper around the `ModifierManager` library (`Libraries/ModifierManager`) that integrates it into e2en's Service/Controller pattern.

It exists to expose the library through `e2en.GetService("ModifiersService")` so other systems can access it the standard way. It also hooks into player lifecycle for automatic cleanup and syncs player stats to the client controller automatically.

The actual modifier logic lives in the library.
