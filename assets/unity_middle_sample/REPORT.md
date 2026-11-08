# MiddleCenter / Center native TextMesh group

Completed exit0, Unity6000.3.10f1(e35f0c77bd8e), Apple M3, Metal. Separate output directory and screenshot filenames; all earlier UpperLeft data retained unchanged. This is exploratory Editor sampling, not original Hearthstone screenshot or strict version match.

Only anchor changed from UpperLeft to MiddleCenter and alignment Left to Center (requested source mapping); corresponding diagnostic note and screenshot names updated. Font import size16 spacing1 padding4 Smooth rounded advance, request46 remain unchanged. Full104-character request then deferred final atlas and all UV export; all104 available with per-glyph nonzero coverage verified.

Two actual TextMesh Renderers inspected. MeshFilter absent for both, sharedMesh unavailable; no native vertices/quad/triangles obtainable by this route and no synthetic geometry supplied. JsonUtility represents unavailable arrays as [] and default meshBounds0; boolean availability flags are authoritative. Actual renderer bounds, transforms and CharacterInfo exported.

Two actual transparent diagnostic camera RTTs exported with distinct names. New camera follows each actual renderer center, orthographicSize3 aspect4, near0.1 far100; 1024x256 ARGB32 Linear depth16 MSAA1, transparent clear, default font material/white text, HDR/MSAA off, layer30, single renderer active. Exact camera positions/rotations in textmesh-supplement.json. These camera settings are diagnostic, not reconstructed original game camera. All screenshot alpha coverage nonzero.

Sources, diffs from prior UpperLeft group, font.meta, complete metrics/atlas/UV, per-character checks and redacted execution log included. No additional dependencies/software or other project changes.
