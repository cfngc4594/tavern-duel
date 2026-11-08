# Exact CommandBuffer temporary2D RT V-edge probe

Actual first execution exit0, Unity6000.3.10f1(e35f0c77bd8e), Apple M3/Metal, Gamma project and active colorSpace. Only new standalone probe and2shader assets in existing isolated project; no installation/login/game/manual-license changes.

Source allocated solely by CommandBuffer.GetTemporaryRT(id,16,16,16,FilterMode.Bilinear,(RenderTextureFormat)16), EXACT six parameters, no wrap assignment, no RenderTexture.GetTemporary substitution. Source format16 is R8; pattern uses red0.2 for Unity UV.y<0.5 (bottom),red0.8 for UV.y>=0.5 (top). GPU commands: allocate/write/copy pattern/bind/sample/release in one command buffer, CPU readback after Graphics.ExecuteCommandBuffer. Separate ARGB32Linear diagnostic targets only for observation.

Actual pattern readback: Unity GetPixel(8,2) red0.2 bottom, GetPixel(8,13) red0.8 top; GetPixel origin bottom-left. Exported PNG top region red204/255, bottom region red51/255. Sample PNG is4pixels horizontal; LEFT TO RIGHT fixedu0.5, v[-0.25,0.25,0.75,1.25]. Actual red values[0.20000000298023225,0.20000000298023225,0.800000011920929,0.800000011920929], corresponding bytes[51,51,204,204], G/B0,A1. Interior controls distinct and correct. Out-of-range values match respective bottom/top edge, supporting measured V Clamp behavior. Repeat would reverse these two outside samples. No W test or inference.

Raw JSON, original small pattern/sample PNGs, source C#/shaders, validation, actual version and redacted log included. Results apply to this installed Unity/API/colorspace, not untested platforms or original runtime.
