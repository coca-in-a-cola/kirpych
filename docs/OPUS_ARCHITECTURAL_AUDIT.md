# Kirpych Architectural Audit (t_kp_12)

## Test suite (godot-xvfb --headless)

| Test | Exit | Result |
|---|---|---|
| test_brick_physics | 0 | 5/5 PASS |
| test_level_02 | 0 | 4/4 PASS |
| test_level_03 | 0 | 4/4 PASS |
| test_campaign_flow | 0 | 3/3 PASS |

The logs show no errors or warnings. The passes mean little: the tests call handlers directly (_on_body_entered, _physics_process(0.5)). They never simulate physics, send input, or check whether a level can be traversed.

## Measured defects

**Controller.** Measured with a new probe, tools/audit/controller_probe.gd, which runs the real brick.tscn on a flat slab:
- Holding W alone reaches 144 km/h (the clamp) in about 8s. It hits 36 km/h in 1.5s and 100 km/h in 4.15s. This breaks the GDD rule that input applies only a weak force. Cause: brick.gd:10-11, acceleration 8.5 against a constant friction of 1.8 m/s^2.
- Carving with D gains speed. Over 3s it goes from 19.9 to 24.5 m/s and turns 95 degrees. Causes: the lateral 1.5x boost at brick.gd:92 and the renormalisation at :97-98. That renormalisation also breaks GDD section 4, which forbids normalising velocity.
- The brick feels like it is on ice. Coasting from 72 km/h takes 11s and 110m to stop.
- The per-axis speed clamp leaks. brick.gd:154 clamps each axis to 40, so a diagonal can reach 56.3 m/s.
- Slope pull is not physical. brick.gd:70 multiplies gravity by slope_accel_factor = 1.8.
- The speedometer counts vertical velocity (:184).
- Jump: apex 2.08m, air time 0.97s. Air vs ground acceleration over 0.5s: 4.18 vs 3.35 m/s, which fits the GDD.

**Camera (camera_rail.gd).**
- It is not a rail at all. Track direction is hardcoded to +Z.
- Line 34 makes the camera follow x * 0.75. As a result, what W means silently rotates with lateral position: 6.6 degrees off at x=4 and 17.7 degrees at x=11. This breaks the GDD 'honest camera' rule.
- Line 36 hard-locks z while x and y are lerped, which risks jitter.
- There is no wall or occlusion handling.
- The input basis includes the camera roll (lines 47-49), so the roll tilt also skews the movement directions.

**Procedural primitives still in use.**

| Level | Count | What |
|---|---|---|
| L1 | 5 | ground BoxMesh 24x130, ramp, tire, awning, helmet |
| L2 | 7 | 3 floors, conveyor, lift, door, helmet |
| L3 | 8 | roof, beam, fan, crane, launch ramp, cradle, net, helmet |

- tarp_canopy, platform_medium, platform_tile, concrete_slab and building_garage are unused.
- All Kenney building GLBs are 1m unit footprints. That makes the site office 2.5x2.4m, the L2 'building' 3.5x5.7x4.5m, and the L3 'building below' 6.5m tall while the roof sits at y=27. The roof floats in the air.
- The L1 'perimeter walls' are four 1.75m stubs.
- The worker model is 0.99m tall, but its capsule is 1.8m. The helmet sphere floats about 0.8m above its head.

**Colliders.**
- L1 start scaffold: the visual is 15.5x12.5m but the collider is only 6.2x10m, so the player sees floor where there is none. The visual top is also 0.05m above the collider.
- L2 Floor2: the visual (30m) is longer than the collider (26m), giving 2m of floor with no collision at each end. Floor1 has the reverse problem: 1m of invisible floor at each end. All floors share one BoxMesh_floor.
- No solid body at all: tire, awning, conveyor and fan are Area3D only, and the L3 cradle and safety net have no colliders.

**Z-fighting.**
- L3 RoofPlatform and NarrowBeam share a top face at y=28.05 over 2.4 sq m (exact, gap 0).
- The L1 awning mesh sinks 1m into YardGround.

**Progression blockers (static geometry, not playtested).**
- L2: Floor2 (top 12.55) meets Floor3 (top 16.55) as a 4m wall at z=65, with no ramp. The jump apex is 2.08m.
- L2: the worker spawns at z=92, behind the door at z=88, and runs to target_door_z = 120. Floor3 ends at z=95, so the worker runs off the edge.

**Prop logic.**
- conveyor_belt.gd:18 drives the whole velocity, including y, toward the belt vector. This kills gravity, jumps and steering.
- bouncy_tire.gd:13 applies a fixed +Z impulse regardless of approach.
- awning_slide.gd:18 hard-resets friction to 1.8 on exit.
- metal_door.gd:22 rotates the door about its centre, not a hinge.
- Determinism breaks: worker_npc.gd:40 uses Time, and :63 uses randf_range.

**Systems.**
- GameManager is not an autoload (project.godot has no [autoload] section). GameManager.instance is always null, so level results are never recorded.
- Missing GDD features: pause on Esc; the score formula; best score; time and fail stats; worker animation and direction.
- config/features still says 4.3 / Forward Plus, while the project uses gl_compatibility on 4.7.2.

**UI.**
- Lilita One has zero Cyrillic glyphs (66 of 66 missing) and lacks the symbols used in UI text. Every Russian label renders in a system fallback font, so the 'Lilita One UI' claim is false. A Cyrillic-capable OFL display font is needed.
- 'Non-clickable buttons' did not reproduce in a real 1280x720 window. All 6 menu buttons and both victory buttons received hover and one click each when clicked at their centres.
  - Under --headless the viewport reports 1280x1280 and gets 0 clicks, so headless runs are not valid UI evidence.
  - Real defects found instead: pressed, focus and disabled styles are unset (main_menu.tscn); the HUD buttons (hud.tscn:135-147) have no styles at all; there is no initial grab_focus; and gameplay keeps running behind the victory panel.
  - The owner's actual repro steps are still needed to confirm which buttons they meant.

**Screenshots.**
- The capture tool exited 0 and wrote four 1280x720 PNGs: menu 32.5 KB, L1 206 KB, L2 13.8 KB, L3 257 KB.
- The 13.8 KB L2 frame is suspiciously small and is likely near-blank; this needs visual confirmation in the next pass.

## Prioritised fixes for the next phase

1. P0 - UI font: switch to a Cyrillic-capable display font.
2. P0 - L2 completability: add a ramp or chute up the 4m step, and correct the worker route/endpoint so it does not run off the floor edge.
3. P0 - Colliders: match visual and collider extents on the L1 scaffold and L2 floors; add solid StaticBody collision under the conveyor, fan, cradle and net (currently Area3D-only or missing).
4. P0 - GameManager: register it as an autoload in project.godot.
5. P1 - Controller: remove the velocity renormalisation and lateral boost (brick.gd:92-98); use speed-dependent friction/input so holding W alone cannot exceed roughly 20-25 km/h; clamp by vector length, not per axis; drop the slope_accel_factor multiplier.
6. P1 - Camera: build real rail segments with a frozen input basis while airborne; remove the x-position-driven yaw lerp; strip roll out of the movement input basis; add a wall/occlusion probe.
7. P1 - Assets: replace every remaining primitive with correctly scaled Kenney GLBs on a uniform scale with separate hand-built colliders; fix the roof/beam z-fight; fix the worker model scale and helmet offset.
8. P2 - Missing features: pause on Esc, score formula + best score persistence, determinism fixes (remove Time/randf_range from gameplay-affecting logic), UI button state styles + initial focus, worker run animation, correct project.godot features string.

## Known gaps in this audit (to close in the next pass)

- The four freshly captured screenshots in artifacts/screenshots/ have not been visually reviewed yet; the L2 screenshot in particular (13.8 KB) needs a human/vision check for a near-blank frame.
- The owner's specific 'half the buttons non-clickable' repro was not reproduced in a real windowed run; needs the owner's exact click sequence to confirm root cause.

## Resolved (t_kp_15)

Fixed in commit `fix(level2,systems): add Floor2->Floor3 connector, fix worker route past map edge, register GameManager autoload`:

- **P0 #2 - L2 Floor2->Floor3 step:** added `RampConveyor_F2toF3` to level_02.tscn. It is an inclined StaticBody3D bed at about 18.4 deg, plus a conveyor_belt.gd drive Area3D, bridging the 4m wall at z=65.
- **P0 #2 - L2 worker route:** `target_door_z` changed 120 -> 93.5, so the worker stops on Floor3, which ends at z=95. worker_npc.gd now applies gravity while running, so it can no longer glide past a floor edge.
- **P0 #4 - GameManager:** registered as the `GameManager` autoload in project.godot. `class_name` was removed because it collided with the autoload name. Levels and the main menu now call the singleton directly.
  - `GameManager.instance` is bound in `_enter_tree`.
  - Headless tests now run in `_initialize()` instead of `_init()`, because autoloads are not registered while `_init` runs.
  - test_campaign_flow.gd TEST 4 asserts that the live autoload records a real level finish.

## Resolved (t_kp_16)

Fixed in commit `fix(colliders): match visual/collider extents on L1/L2 floors, add solid bodies to props, fix L3 roof z-fight`. Closes P0 #3 and the roof/beam z-fight item from P1 #7.

- **L1 StartScaffold:** the collider now matches the scaled `platform_large.glb` visual. Both measure (6.20, 0.55, 10.00) at y 11.50-12.05.
- **L2 floors:** Floor1_LoadingBay, Floor2_Mezzanine and Floor3_UpperBay each have their own BoxMesh/BoxShape3D pair, sized identically: 14x1x32, 14x1x26 and 14x1x30. The floors previously shared one mesh resource, so their visuals and colliders drifted apart. level_02.gd now respawns at z=5, above the now-solid conveyor, instead of in front of its 0.55 m leading edge.
- **Props get solid bodies:** a `StaticBody3D` was added alongside the existing trigger `Area3D` on:
  - bouncy_tire (`SolidBody`, cylinder)
  - awning_slide (`SolidBody`)
  - conveyor_belt (`SolidBody`)
  - exhaust_fan (`SolidBody`)
  - cradle_finish (`CradleBaseBody`)
  - its safety net (`SafetyNetBody`, inside cradle_finish.tscn)
- **L3 roof/beam z-fight:** NarrowBeam was lowered to y=27.6, so its top (28.00) sits 0.05 m below the RoofPlatform top (28.05). ExhaustFan was moved to (27.65, z=40) so it sits on the beam end.
- **Verification:**
  - `tests/test_colliders.gd`: 12/12 visual/collider extent pairs match at 0.0000 deviation. The full headless suite passes.
  - `tools/audit/geometry_ui_audit.gd` reports no MESH_COLLIDER_MISMATCH for level geometry. The only remaining mismatch is the intentional WorkerNPC helmet-vs-capsule pair.
  - The audit still lists RoofPlatform<->NarrowBeam under ZFIGHT, with `gap=0.0500`. That is because the step equals the tool's `ZFIGHT_EPS` (0.05) and float rounding puts it just under the threshold.
- **New probes:** `tools/audit/prop_traversal_probe.gd` and `tools/audit/conveyor_lift_gap_probe.gd`.
- **Screenshots:** re-captured. The level_02 frame still shows a blown-out white floor on a black background, but the pre-change baseline looks the same, so this is not a regression from this change.

### Known open issue at t_kp_16 close

- The L2 conveyor-to-lift gap was moved to Resolved in t_kp_17 (see below).

## Resolved (t_kp_17)

- **L2 conveyor-to-lift progression gap** (z~28.5 to the MovingLift at z33-39; it was 0/90 traversal strategies reaching Floor2 at t_kp_16). Fixed in commit `2780e9d` with three changes:
  - Floor1_LoadingBay was extended to 14x1x33, centred at z=16.5.
  - MovingLift was re-seated at y=-0.35 with `travel_distance=13.0`, and a ToeGuard collider was added under the deck edge.
  - A `LiftShaftBackWall` StaticBody3D was added at z=39.2.
- **Verification:**
  - `tools/audit/conveyor_lift_gap_probe.gd` now reaches Floor2 in **53/108** strategy-runs. That includes 18/18 for the new `board` and `brake+board` strategies.
  - The full headless suite passes (test_brick_physics, test_level_02, test_level_03, test_campaign_flow, test_colliders, all exit 0).
  - test_colliders confirms the Floor1 visual and collider both span z 0..33.
- **L2 blown-out lighting:** the WorldEnvironment used a flat background (`background_mode=1`), color ambient, and a 1.6-energy sun. It now matches the L1/L3 pattern:
  - a procedural overcast industrial sky (`ProceduralSkyMaterial_overcast`, `background_mode=2`)
  - sky ambient (`ambient_light_source=3`)
  - DirectionalLight energy 1.0

  In the 1280x720 gl_compatibility still, pure-white pixels dropped from 37.3% to 0.1%, dark pixels (L<=35) from 52.5% to 11.8%, and mid-tones rose from 10.1% to 88.0%.
- **Residual z-fights** (`geometry_ui_audit.gd` now reports neither):
  - L3: NarrowBeam was lowered to y=27.5 (top 27.90, a 0.15 m step down from the roof, within the 0.35 snap). ExhaustFan was lowered to y=27.55 so it keeps its 0.05 m step below the beam.
  - L2: RampConveyor_F2toF3 (bed and drive Area3D) now pivots about its Floor2 edge (z=53, y=12.55), steepened 18.43 -> 18.82 deg. Its upper end now sits at y=16.63, 0.08 m *above* Floor3 (16.55), so the brick steps down onto Floor3 within snap.
    - Lowering that end instead would have created a 5 cm step up, which the box-shaped brick cannot climb.
- **Verification:**
  - `tools/audit/ramp_beam_traversal_probe.gd`: Floor2->Floor3 is reached from all three start positions, and the roof->beam end is reached from both.
  - The full suite passes. `conveyor_lift_gap_probe` still reports 53/108.
