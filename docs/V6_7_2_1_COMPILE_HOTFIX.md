# v6.7.2.1 Compile Hotfix

## Cause

The generated MQL5 source contained a literal newline inside this quoted string:

```cpp
FileWriteString(handle, canonical_header + "
");
```

That caused the parser errors beginning at line 2327.

## Fix

The statement is now:

```cpp
FileWriteString(handle, canonical_header + "\r\n");
```

No trading logic, candidate logging, loss-cooldown logic, schema order, or trade-export behaviour was changed.
