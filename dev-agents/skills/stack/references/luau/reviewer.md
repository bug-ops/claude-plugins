# Luau — Code Review Rules

## Checklist Additions

### Error Handling
- [ ] Every fallible engine call (DataStores, HTTP, marketplace, teleport) wrapped in `pcall`, with the success flag checked?
- [ ] Errors in spawned threads and remote handlers logged with context, never silently dropped?
- [ ] `error` called with a level that blames the right frame; structured errors used consistently?

### Type Safety
- [ ] `--!strict` on every touched Luau file; no downgraded modes?
- [ ] No `:: any`; every `::` cast carries a reason?
- [ ] Remote arguments, JSON, DataStore values, and attributes treated as `unknown` and validated before use?
- [ ] `FindFirstChild`/`WaitForChild` results handled as possibly `nil`; instance classes checked with `IsA`?
- [ ] Tagged unions handled for every tag, with an `error` on the unknown branch?

### Roblox Safety & Security
- [ ] Every `OnServerEvent`/`OnServerInvoke` handler validates type, range, NaN/infinity, ownership, and rate before acting?
- [ ] No server authority delegated to the client (damage, currency, positions, cooldowns)?
- [ ] No secrets or server-only logic in `ReplicatedStorage` or client scripts; secrets read through the Secrets Store on the server?
- [ ] User-generated text shown to other players passed through `TextService` filtering?
- [ ] No `loadstring`, `getfenv`/`setfenv`, or `require(assetId)` of third-party assets?
- [ ] No `RemoteFunction:InvokeClient`?

### Lifecycle
- [ ] Every new connection, thread, and instance has a cleanup path (player leaving, round ending, object destroyed)?
- [ ] DataStore writes use `UpdateAsync` where concurrent writers exist; data saved on `PlayerRemoving` and `BindToClose`?

### Testing
- [ ] No focused or skipped tests left in (`fit`, `it.only`, `itFOCUS`, `xit`, `itSKIP`)?
- [ ] Logic that does not need the engine is tested outside it (Lune) or through pure modules?

### Formatting
- 🔵 NITPICK formatting findings are fixed by running StyLua (`stylua .`), never by hand.

## Modern Language Review

Flag 🟢 SUGGESTION where a newer Luau feature replaces a workaround: string interpolation (`` `{name}: {count}` ``) instead of `..` chains and `string.format` for simple cases, compound assignment (`+=`), `if-then-else` expressions instead of `a and b or c` (which breaks when `b` is falsy), generalized iteration (`for k, v in t do`) instead of `pairs`/`ipairs` where the project adopted it, `table.clone`/`table.freeze`, `buffer` for binary data instead of string packing, floor division `//`, `task.*` instead of deprecated globals. Lua mode: suggest only what the declared Lua version supports.

## Luau-Specific Review Points

### Unvalidated Remote Arguments

```luau
-- 🔴 CRITICAL: client controls the item id and the amount
-- ❌ BAD
BuyItem.OnServerEvent:Connect(function(player, itemId, amount)
	Shop.purchase(player, itemId, amount)
end)

-- ✅ GOOD
BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown, amount: unknown)
	if typeof(itemId) ~= "string" or not Catalog[itemId] then return end
	if typeof(amount) ~= "number" or amount ~= amount or amount < 1 or amount > 99 or amount % 1 ~= 0 then return end
	if not RateLimit.allow(player, "BuyItem") then return end
	Shop.purchase(player, itemId, amount)
end)
```

### Leaked Connections

```luau
-- 🟡 IMPORTANT: the connection outlives the character and keeps it in memory
-- ❌ BAD
player.CharacterAdded:Connect(function(character)
	RunService.Heartbeat:Connect(function() updateAura(character) end)
end)

-- ✅ GOOD
player.CharacterAdded:Connect(function(character)
	local conn = RunService.Heartbeat:Connect(function() updateAura(character) end)
	player.CharacterRemoving:Once(function() conn:Disconnect() end)
end)
```

### `and`/`or` Ternary

```luau
-- 🟡 IMPORTANT: returns the fallback when the value is `false`
-- ❌ BAD
local enabled = settings.enabled ~= nil and settings.enabled or true

-- ✅ GOOD
local enabled = if settings.enabled ~= nil then settings.enabled else true
```

### Comment Hygiene

```luau
-- 🟢 SUGGESTION: Redundant comment, no complexity to justify it
-- ❌ BAD
-- Increment the retry counter by one.
retryCount += 1

-- ✅ GOOD
retryCount += 1
```

## Tools

```bash
rojo sourcemap default.project.json -o sourcemap.json && luau-lsp analyze ...   # type check (exact flags: toolchain.md)
selene .                                                                        # lint
stylua --check .                                                                # format check
```
