# v6.6.3.1 Compile Hotfix

## Fix

Removed invalid global initializer:

```cpp
Athena_EstimateEntryPriceFromDirection(event.symbol, event.direction)
```

That expression requires a local `event` object and cannot be evaluated at global scope.

The entry-price proxy is now assigned inside `Athena_RecordAcceptedCandidateContext()`.

## No strategy changes.
