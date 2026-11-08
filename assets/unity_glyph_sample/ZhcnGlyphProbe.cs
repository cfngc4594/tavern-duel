using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static class ZhcnGlyphProbe {
 const string FontPath="Assets/Fonts/GLEI00M_t_Outline__4016971574774461928.ttf";
 const int Size=46; // Requested sampling size, not original Font import size (16).
 static readonly string[] Texts={"冰风雪人","吸取生命","造成2点伤害。为你的英雄恢复2点生命值。"};
 [Serializable] class Glyph {public string character; public int codepoint,advance,minX,maxX,minY,maxY,glyphWidth,glyphHeight; public bool available; public Vector2 uvBottomLeft,uvBottomRight,uvTopLeft,uvTopRight;}
 [Serializable] class TextResult {public string text; public Bounds rendererWorldBounds; public bool enabled; public float characterSize; public int fontSize;}
 [Serializable] class Result {public string status,unityVersion,graphicsDevice,fontName,fontFileSha256,importSettingsJson,legacyBoundsSetting,notes; public int requestFontSize,originalImportSize,atlasWidth,atlasHeight; public float fontAscent,fontLineHeight; public List<Glyph> glyphs=new List<Glyph>(); public List<TextResult> texts=new List<TextResult>();}
 static readonly List<GameObject> Objects=new List<GameObject>(); static Font font; static Result result;
 static string Out {get {var a=Environment.GetCommandLineArgs(); int i=Array.IndexOf(a,"-probeOutput"); return i>=0&&i+1<a.Length?Path.GetFullPath(a[i+1]):Path.GetFullPath("ProbeOutput");}}
 [MenuItem("Tools/Export zhCN glyph probe")]
 public static void Run() {try {
  Directory.CreateDirectory(Out);
  if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null) throw new Exception("Graphics device is Null. Run without -nographics, with a working desktop/GPU.");
  AssetDatabase.ImportAsset(FontPath,ImportAssetOptions.ForceSynchronousImport);
  var imp=(TrueTypeFontImporter)AssetImporter.GetAtPath(FontPath);
  imp.fontSize=16; imp.fontTextureCase=FontTextureCase.Dynamic; imp.characterSpacing=1; imp.characterPadding=4; imp.includeFontData=true;
  imp.fontRenderingMode=FontRenderingMode.Smooth; imp.shouldRoundAdvanceValue=true;
  imp.fontNames=new[]{"AR LisuGB"}; imp.fontReferences=new Font[0];
  // No public API exposed for this legacy flag: set only when actually present and record result.
  var so=new SerializedObject(imp); var prop=so.FindProperty("m_UseLegacyBoundsCalculation")??so.FindProperty("useLegacyBoundsCalculation");
  string legacy="unavailable; not set"; if(prop!=null&&prop.propertyType==SerializedPropertyType.Boolean){prop.boolValue=true;so.ApplyModifiedPropertiesWithoutUndo();legacy="set true through existing SerializedProperty: "+prop.propertyPath;}
  imp.SaveAndReimport(); font=AssetDatabase.LoadAssetAtPath<Font>(FontPath);
  result=new Result{status="pending",unityVersion=Application.unityVersion,graphicsDevice=SystemInfo.graphicsDeviceName,fontName=font.name,requestFontSize=Size,originalImportSize=16,fontAscent=font.ascent,fontLineHeight=font.lineHeight,importSettingsJson=EditorJsonUtility.ToJson(imp,true),legacyBoundsSetting=legacy,notes="Unity native dynamic Font sampling only; NOT original UberText, original card screenshot, or verified native-client pixel reproduction. No fallback font installed. Body characters sampled from title font for diagnostics, not a body-font mapping claim. TextMesh characterSize=1, anchor=UpperLeft, alignment=Left, style=Normal; not original card scale."};
  using(var sha=System.Security.Cryptography.SHA256.Create()) result.fontFileSha256=BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(FontPath))).Replace("-","").ToLowerInvariant();
  foreach(var text in Texts){var go=new GameObject("Probe_"+text);Objects.Add(go); var tm=go.AddComponent<TextMesh>();tm.font=font;tm.fontSize=Size;tm.fontStyle=FontStyle.Normal;tm.characterSize=1;tm.anchor=TextAnchor.UpperLeft;tm.alignment=TextAlignment.Left;tm.richText=false;tm.text=text;go.GetComponent<Renderer>().sharedMaterial=font.material;}
  EditorApplication.QueuePlayerLoopUpdate(); EditorApplication.delayCall+=Export;
 } catch(Exception e){Fail(e);} }
 static void Export(){try{
  string chars=new string(string.Concat(Texts).Distinct().ToArray());
  font.RequestCharactersInTexture(chars,Size,FontStyle.Normal);
  foreach(var go in Objects){var tm=go.GetComponent<TextMesh>();result.texts.Add(new TextResult{text=tm.text,rendererWorldBounds=go.GetComponent<Renderer>().bounds,enabled=go.GetComponent<Renderer>().enabled,characterSize=tm.characterSize,fontSize=tm.fontSize});}
  // Read all UVs only after the final bulk request; no subsequent font-size requests.
  foreach(char c in chars){CharacterInfo ci;bool ok=font.GetCharacterInfo(c,out ci,Size,FontStyle.Normal);result.glyphs.Add(new Glyph{character=c.ToString(),codepoint=c,available=ok,advance=ci.advance,minX=ci.minX,maxX=ci.maxX,minY=ci.minY,maxY=ci.maxY,glyphWidth=ci.glyphWidth,glyphHeight=ci.glyphHeight,uvBottomLeft=ci.uvBottomLeft,uvBottomRight=ci.uvBottomRight,uvTopLeft=ci.uvTopLeft,uvTopRight=ci.uvTopRight});}
  Texture atlas=font.material.mainTexture;if(atlas==null||atlas.width==0)throw new Exception("No font atlas produced");
  result.atlasWidth=atlas.width;result.atlasHeight=atlas.height;
  var old=RenderTexture.active;var rt=RenderTexture.GetTemporary(atlas.width,atlas.height,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);
  Texture2D copy=null;try{Graphics.Blit(atlas,rt);RenderTexture.active=rt;copy=new Texture2D(atlas.width,atlas.height,TextureFormat.RGBA32,false,true);copy.ReadPixels(new Rect(0,0,atlas.width,atlas.height),0,0);copy.Apply();File.WriteAllBytes(Path.Combine(Out,"atlas_rgba.png"),copy.EncodeToPNG());
   // Alpha separately supports inspection of Unity's font-coverage channel.
   var pixels=copy.GetPixels32();for(int i=0;i<pixels.Length;i++){byte a=pixels[i].a;pixels[i]=new Color32(a,a,a,255);}copy.SetPixels32(pixels);copy.Apply();File.WriteAllBytes(Path.Combine(Out,"atlas_alpha.png"),copy.EncodeToPNG());
  }finally{RenderTexture.active=old;RenderTexture.ReleaseTemporary(rt);if(copy!=null)UnityEngine.Object.DestroyImmediate(copy);}
  result.status=result.glyphs.All(g=>g.available)?"sampled":"partial_missing_glyphs";File.WriteAllText(Path.Combine(Out,"glyphs.json"),JsonUtility.ToJson(result,true));
  foreach(var go in Objects)UnityEngine.Object.DestroyImmediate(go);Objects.Clear();Debug.Log("Glyph probe exported: "+Out);if(Application.isBatchMode)EditorApplication.Exit(result.status=="sampled"?0:2);
 }catch(Exception e){Fail(e);}}
 static void Fail(Exception e){Directory.CreateDirectory(Out);File.WriteAllText(Path.Combine(Out,"ERROR.txt"),e.ToString());Debug.LogException(e);if(Application.isBatchMode)EditorApplication.Exit(1);}
}
