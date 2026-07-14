# Graph Report - src  (2026-07-15)

## Corpus Check
- 340 files · ~67,127 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 468 nodes · 622 edges · 112 communities (106 shown, 6 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 62 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c91b5964`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- RPCommandsModule.Init
- CombatModule.luau
- CondicionesModule.luau
- init.client.luau
- GatherModule.luau
- ClientCombat.client.luau
- ClientCombat.client.luau
- InventoryConfig.luau
- RagdollModule.SetRagdoll
- ClientCombat.client.luau
- ClientCombat.client.luau
- ClientCombat.client.luau
- ClientCombat.client.luau
- ClientCombat.client.luau
- ClientCombat.client.luau
- PermadeathModule.luau
- ChestManager.server.luau
- RelicManager.server.luau
- SurvivalModule.luau
- VFXManager.server.luau
- LocalScript.client.luau
- LocalScript.client.luau
- LocalScript.client.luau
- LocalScript.client.luau
- UIManager.luau
- ArmorModule.luau
- BossHealthbarModule.luau
- TalentCommandServer.server.luau
- TitleManager.server.luau
- FishingClient.client.luau
- FishingClient.client.luau
- ItemNotification.luau

## God Nodes (most connected - your core abstractions)
1. `RPCommandsModule.Init()` - 18 edges
2. `CombatModule.CreateHitbox()` - 16 edges
3. `handleImpact()` - 11 edges
4. `CombatModule.ThrowShield()` - 10 edges
5. `LoreModule.SaveAllData()` - 9 edges
6. `AdvancedInjuryModule.RollForInjury()` - 8 edges
7. `CombatModule.PlayCharacterSound()` - 8 edges
8. `onPlayerDied()` - 7 edges
9. `spawnEarthFissure()` - 7 edges
10. `CombatModule.CreateStrongRightHitbox()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `RPCommandsModule.Init()` --calls--> `CondicionesModule.Remove()`  [INFERRED]
  src/ServerScriptService/ServerModules/RPCommandsModule.luau → src/ServerScriptService/ServerModules/CondicionesModule.luau
- `hasCompletedLevel()` --calls--> `MagicConfig.GetSpellAttributeName()`  [INFERRED]
  src/ServerScriptService/MagicService.server.luau → src/ReplicatedStorage/Modules/MagicConfig.luau
- `LoreModule.SaveTalents()` --calls--> `MagicConfig.GetSpellAttributeName()`  [INFERRED]
  src/ServerScriptService/ServerModules/LoreModule.luau → src/ReplicatedStorage/Modules/MagicConfig.luau
- `handleHonorCommand()` --calls--> `LoreModule.SaveAllData()`  [INFERRED]
  src/ServerScriptService/HonorCommandHandler.server.luau → src/ServerScriptService/ServerModules/LoreModule.luau
- `onPlayerDied()` --calls--> `CondicionesModule.HasCondicion()`  [INFERRED]
  src/ServerScriptService/LifeManager.server.luau → src/ServerScriptService/ServerModules/CondicionesModule.luau

## Import Cycles
- None detected.

## Communities (112 total, 6 thin omitted)

### Community 0 - "RPCommandsModule.Init"
Cohesion: 0.06
Nodes (25): MagicConfig.GetSpellAttributeName(), cleanName(), cleanRequests(), handleChat(), handleHonorCommand(), hasCompletedLevel(), onPlayerAdded(), updateDailyAttempts() (+17 more)

### Community 1 - "CombatModule.luau"
Cohesion: 0.16
Nodes (28): MagicConfig.GetAdjustedColor(), freezeCharacter(), handleImpact(), scaleNumberSequence(), spawnEarthFissure(), spawnProjectile(), AdvancedInjuryModule.RollForInjury(), CombatModule.ApplyHitSlow() (+20 more)

### Community 2 - "CondicionesModule.luau"
Cohesion: 0.13
Nodes (17): setupPlayer(), applyPKInventoryLoss(), onPlayerDied(), trackPlayer(), wipeAllStores(), AdvancedInjuryModule.AddInjury(), AdvancedInjuryModule.ApplyTreatment(), AdvancedInjuryModule.ClearPlayer() (+9 more)

### Community 3 - "init.client.luau"
Cohesion: 0.14
Nodes (18): animateTool(), configureAnimationSet(), getRigScale(), getTool(), getToolAnim(), keyFrameReachedFunc(), move(), onClimbing() (+10 more)

### Community 4 - "GatherModule.luau"
Cohesion: 0.20
Nodes (11): initializeHarvestable(), findResourceRoot(), GatherModule.OnHit(), GatherModule.PlayHitEffect(), getResourceHealth(), getResourcePos(), scheduleRespawn(), spawnLoot() (+3 more)

### Community 5 - "ClientCombat.client.luau"
Cohesion: 0.32
Nodes (9): attack(), checkHitbox(), heavy(), playCombatSound(), playHitEffect(), setNoJump(), startBlockEffect(), stopBlockEffect() (+1 more)

### Community 6 - "ClientCombat.client.luau"
Cohesion: 0.32
Nodes (9): attack(), checkHitbox(), heavy(), playCombatSound(), playHitEffect(), setNoJump(), startBlockEffect(), stopBlockEffect() (+1 more)

### Community 7 - "InventoryConfig.luau"
Cohesion: 0.33
Nodes (6): InventoryConfig.GetMaxStack(), InventoryConfig.IsBlacklisted(), InventoryConfig.IsStackable(), consolidateContainer(), onPlayerAdded(), watchContainer()

### Community 8 - "RagdollModule.SetRagdoll"
Cohesion: 0.27
Nodes (5): CarryModule.Carry(), CarryModule.Drop(), createColliderPart(), RagdollModule.SetRagdoll(), RagdollModule.SetupCharacter()

### Community 9 - "ClientCombat.client.luau"
Cohesion: 0.40
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 10 - "ClientCombat.client.luau"
Cohesion: 0.38
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 11 - "ClientCombat.client.luau"
Cohesion: 0.40
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 12 - "ClientCombat.client.luau"
Cohesion: 0.40
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 13 - "ClientCombat.client.luau"
Cohesion: 0.38
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 14 - "ClientCombat.client.luau"
Cohesion: 0.40
Nodes (7): attack(), cleanup(), heavy(), playCombatSound(), startBlockEffect(), stopBlockEffect(), toggleBlock()

### Community 16 - "PermadeathModule.luau"
Cohesion: 0.57
Nodes (7): PermadeathModule.GetFullName(), PermadeathModule.OnPlayerDied(), PermadeathModule.PostEmbed(), PermadeathModule.SendWebhook(), PermadeathModule.SetState(), PermadeathModule.TrackPlayer(), postWebhook()

### Community 18 - "ChestManager.server.luau"
Cohesion: 0.57
Nodes (5): closeChestForPlayer(), countViewers(), playSound(), scanForChests(), setupChest()

### Community 19 - "RelicManager.server.luau"
Cohesion: 0.87
Nodes (5): equipRelic(), getEquippedRelicsFolder(), setupPlayer(), unequipSlot(), updateRelicBuffs()

### Community 21 - "VFXManager.server.luau"
Cohesion: 0.60
Nodes (5): applyBurnEffect(), getHumanoidsInRadius(), handleExplosion(), handleFuego(), playSoundAtPosition()

### Community 22 - "LocalScript.client.luau"
Cohesion: 0.53
Nodes (5): clearIndicator(), createIndicator(), nextItem(), prevItem(), updateUI()

### Community 23 - "LocalScript.client.luau"
Cohesion: 0.67
Nodes (5): clearGhost(), createGhost(), nextItem(), prevItem(), updateUI()

### Community 24 - "LocalScript.client.luau"
Cohesion: 0.53
Nodes (5): clearIndicator(), createIndicator(), nextItem(), prevItem(), updateUI()

### Community 25 - "LocalScript.client.luau"
Cohesion: 0.67
Nodes (5): clearGhost(), createGhost(), nextItem(), prevItem(), updateUI()

### Community 26 - "UIManager.luau"
Cohesion: 0.60
Nodes (3): UIManager.Init(), UIManager.SetBarValue(), UIManager.Update()

### Community 28 - "ArmorModule.luau"
Cohesion: 0.90
Nodes (4): ArmorModule.Equip(), ArmorModule.Toggle(), ArmorModule.Unequip(), ArmorModule.UpdateStats()

### Community 29 - "BossHealthbarModule.luau"
Cohesion: 0.70
Nodes (4): BossHealthbarModule.BroadcastHide(), BossHealthbarModule.BroadcastUpdate(), BossHealthbarModule.DisconnectConns(), BossHealthbarModule.TrackTarget()

## Knowledge Gaps
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RPCommandsModule.Init()` connect `RPCommandsModule.Init` to `PermadeathModule.luau`, `CondicionesModule.luau`, `BossHealthbarModule.luau`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `LoreModule.SaveAllData()` connect `RPCommandsModule.Init` to `CombatModule.luau`, `CondicionesModule.luau`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `AdvancedInjuryModule.RollForInjury()` connect `CombatModule.luau` to `CondicionesModule.luau`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Are the 17 inferred relationships involving `RPCommandsModule.Init()` (e.g. with `AdvancedInjuryModule.AddInjury()` and `AnsiedadModule.Trigger()`) actually correct?**
  _`RPCommandsModule.Init()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `CombatModule.CreateHitbox()` (e.g. with `AdvancedInjuryModule.RollForInjury()` and `CondicionesModule.HasCondicion()`) actually correct?**
  _`CombatModule.CreateHitbox()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 7 inferred relationships involving `handleImpact()` (e.g. with `MagicConfig.GetAdjustedColor()` and `AdvancedInjuryModule.RollForInjury()`) actually correct?**
  _`handleImpact()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `LoreModule.SaveAllData()` (e.g. with `handleChat()` and `handleHonorCommand()`) actually correct?**
  _`LoreModule.SaveAllData()` has 5 INFERRED edges - model-reasoned connections that need verification._