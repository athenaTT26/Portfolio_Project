# v6.6.4.1 Symbol Compile Hotfix

Fixes compile error caused by an out-of-scope `symbol` reference.

The resolver now uses:

```cpp
trade_event.symbol
```

No strategy changes.
