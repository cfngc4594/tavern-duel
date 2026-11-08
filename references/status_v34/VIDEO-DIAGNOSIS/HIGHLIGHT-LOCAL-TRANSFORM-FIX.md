# v34 highlight flicker correction

The original failed clip and diagnostic are retained under `qa/v34/final-status-clip` and `qa/v34/target-flicker-diagnostic`.

## Observed defect

During a static Yeti target highlight, the live actor's board-scale interpolation approached 1. The previous adapter computed `inverse(actor.global_transform) * child.global_transform`. That world-space floating-point roundtrip perturbed the original square plane bounds. The unmodified source resolution formula consequently alternated among 256×255, 255×256 and 256×256. Pipeline generation increased almost every frame and reallocated render targets. Same-frame root, C and T captures at frames 73–76 all lacked the visible gold outline, although a post-draw mask was nonempty; frames 77–78 restored it. This was not an encoder-only failure. The initially suspected lower-right texture artifact was independently retracted as an existing board prop.

## Minimal production correction

Only `native_target_highlight.gd`, `native_target_highlight_gpu.gd` and `native_highlight.gd` changed from checkpoint df198c9b71c7ef391094194f778bf235190dcb3d776f8bbb1007cbb79e3eba67.

The mask now composes source-local transforms to the Actor or a common ancestor, excluding common world transforms entirely. Attached status geometry uses the existing registered projection anchor. For minions that anchor is assigned the Actor transform each frame; for hero proxies the existing common registration precedes the authored source root scale 1.11, so only that local root transform is inverted. Ordinary unregistered attachments use the real common ancestor. Real attached source animation remains part of the mask signature.

No epsilon, arbitrary image-size rounding, fit adjustment, UPDATE_ALWAYS, exposure change, material equation change or shader-time change was added. Original bounds, resolution truncation, source mesh/tag selection and ten rendering passes remain unchanged. The existing status-before-highlight update order is preserved. Source worker independently reviewed the local-chain/registration semantics.

## Evidence

- New runtime checkpoint: `checkpoints/local-highlight-transform-before-gpu.json`, combined SHA e9026bb14003193c8939f883022d073e546ed07bc9febec95736e637a5725d96.
- CPU source plane/mesh/local-chain regression: 518/518, exit 0. Includes minion/hero, changing common world translation/rotation/nonuniform scale, Actor-scale interpolation, exact RT-dimension invariance, separate registered status anchors and actual local attachment changes.
- Reproduction after correction uses the same 0–90 frame input/readback schedule; only its output folder changes to `qa/v34/target-flicker-after-local`.
- In the newly captured 73–78 sequence, Yeti has a stable 256×256 target, one generation, one completed update, one texture RID and one mask key. The prior frame-75 outline is visible. Final independent six-frame pixel verdict and longer clip are owned by QA and must be read before treating the full delivery as accepted.

The low-level backend scheduling reason a resized target was unavailable to C/T at their sampling instant is not separately instrumented. The adapter's unnecessary world-roundtrip-driven target resizing is directly observed; its removal eliminates that churn without changing the original rendering equations.
