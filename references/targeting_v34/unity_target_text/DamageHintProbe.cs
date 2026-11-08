using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
public static class DamageHintProbe {
 const string FontPath="Assets/Fonts/GLEI00M_t_Outline__4016971574774461928.ttf";
 static int group;
 static Font font;
 static List<GameObject> objects=new List<GameObject>();
 [Serializable] class Glyph {public string character;public bool available;public int advance,minX,maxX,minY,maxY,glyphWidth,glyphHeight;public Vector2 uvBottomLeft,uvBottomRight,uvTopLeft,uvTopRight;}
 [Serializable] class TextResult {public string text,anchor,alignment,fontStyle;public bool richText;public int fontSize;public float characterSize,lineSpacing;public Vector3 localPosition,localScale;public Quaternion localRotation;public Bounds localBounds,worldBounds;}
 [Serializable] class Result {public string status,unityVersion,graphicsDevice,graphicsBackend,fontSha256,importSettingsJson,characters,notes;public int fontSize,atlasWidth,atlasHeight;public List<Glyph> glyphs=new List<Glyph>();public List<TextResult> texts=new List<TextResult>();}
 static string Output {get {var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,"-probeOutput");return i>=0&&i+1<a.Length?Path.GetFullPath(a[i+1]):Path.GetFullPath("DamageHintOutput");}}
 static string[] Texts {get{return new[]{"造成1点伤害。","造","成","1","点","伤","害","。","|","|\n|"};}}
 static int Size {get{return 40;}}
 static float Scale {get{return .02449999935925007f;}}
 public static void Run(){try{Directory.CreateDirectory(Output);if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null)throw new Exception("Native GPU required");group=0;Prepare();}catch(Exception e){Fail(e);}}
 static void Prepare(){try{
  font=AssetDatabase.LoadAssetAtPath<Font>(FontPath);if(font==null)throw new Exception("Existing GLEI font unavailable");
  foreach(var text in Texts)foreach(float scale in new[]{Scale,1f}){var go=new GameObject("DamageHint_"+text+"_"+scale);objects.Add(go);var tm=go.AddComponent<TextMesh>();tm.font=font;tm.fontSize=Size;tm.fontStyle=FontStyle.Normal;tm.characterSize=scale;tm.lineSpacing=1;tm.anchor=TextAnchor.MiddleCenter;tm.alignment=TextAlignment.Center;tm.richText=true;tm.text=text;go.GetComponent<Renderer>().sharedMaterial=font.material;}
  font.RequestCharactersInTexture(new string(string.Concat(Texts).Where(c=>c!='\n').Distinct().ToArray()),Size,FontStyle.Normal);EditorApplication.QueuePlayerLoopUpdate();EditorApplication.delayCall+=Export;
 }catch(Exception e){Fail(e);}}
 static void Export(){try{
  var dir=Path.Combine(Output,"font"+Size);Directory.CreateDirectory(dir);
  var r=new Result{status="measured",fontSize=Size,unityVersion=Application.unityVersion,graphicsDevice=SystemInfo.graphicsDeviceName,graphicsBackend=SystemInfo.graphicsDeviceType.ToString(),importSettingsJson=EditorJsonUtility.ToJson(AssetImporter.GetAtPath(FontPath),true),characters=new string(string.Concat(Texts).Where(c=>c!='\n').Distinct().ToArray()),notes="Actual runtime CharacterInfo and Renderer bounds at requested characterSize AND1, no inferred replacement. Existing isolated importer preserved. Each size exports all final UVs and atlas before any next-size request. Exploratory Unity6000.3.10f1, not original-client screenshot or runtime certification. TextMesh richText=true, offsetZ0, tabSize4, default white vertex color and font.material. No diagnostic camera constructed."};
  using(var sha=System.Security.Cryptography.SHA256.Create())r.fontSha256=BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(FontPath))).Replace("-","").ToLowerInvariant();if(r.fontSha256!="b540fd60e6f44d3263c971861ebfec2b79788b20b94b2c753431b4480108e3e5")throw new Exception("GLEI SHA mismatch");
  foreach(char c in r.characters){CharacterInfo ci;bool ok=font.GetCharacterInfo(c,out ci,Size,FontStyle.Normal);if(!ok)r.status="missing_characters";r.glyphs.Add(new Glyph{character=c.ToString(),available=ok,advance=ci.advance,minX=ci.minX,maxX=ci.maxX,minY=ci.minY,maxY=ci.maxY,glyphWidth=ci.glyphWidth,glyphHeight=ci.glyphHeight,uvBottomLeft=ci.uvBottomLeft,uvBottomRight=ci.uvBottomRight,uvTopLeft=ci.uvTopLeft,uvTopRight=ci.uvTopRight});}
  foreach(var go in objects){var tm=go.GetComponent<TextMesh>();var rend=go.GetComponent<Renderer>();r.texts.Add(new TextResult{text=tm.text,richText=tm.richText,anchor=tm.anchor.ToString(),alignment=tm.alignment.ToString(),fontStyle=tm.fontStyle.ToString(),fontSize=tm.fontSize,characterSize=tm.characterSize,lineSpacing=tm.lineSpacing,localPosition=go.transform.localPosition,localRotation=go.transform.localRotation,localScale=go.transform.localScale,localBounds=rend.localBounds,worldBounds=rend.bounds});}
  var atlas=font.material.mainTexture;if(atlas==null)throw new Exception("No font atlas");r.atlasWidth=atlas.width;r.atlasHeight=atlas.height;var old=RenderTexture.active;var rt=RenderTexture.GetTemporary(atlas.width,atlas.height,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);Texture2D tex=null;try{Graphics.Blit(atlas,rt);RenderTexture.active=rt;tex=new Texture2D(atlas.width,atlas.height,TextureFormat.RGBA32,false,true);tex.ReadPixels(new Rect(0,0,atlas.width,atlas.height),0,0);tex.Apply();File.WriteAllBytes(Path.Combine(dir,"atlas_rgba.png"),tex.EncodeToPNG());var pixels=tex.GetPixels32();for(int i=0;i<pixels.Length;i++){byte a=pixels[i].a;pixels[i]=new Color32(a,a,a,255);}tex.SetPixels32(pixels);tex.Apply();File.WriteAllBytes(Path.Combine(dir,"atlas_alpha.png"),tex.EncodeToPNG());}finally{RenderTexture.active=old;RenderTexture.ReleaseTemporary(rt);if(tex!=null)UnityEngine.Object.DestroyImmediate(tex);}
  File.WriteAllText(Path.Combine(dir,"glyphs-bounds.json"),JsonUtility.ToJson(r,true));File.Copy(FontPath+".meta",Path.Combine(dir,"font.ttf.meta"),true);foreach(var go in objects)UnityEngine.Object.DestroyImmediate(go);objects.Clear();Debug.Log("Damage hint text group exported size="+Size+" status="+r.status);
  if(r.status!="measured")throw new Exception("Missing glyphs; inspect group result");group++;if(group<1)EditorApplication.delayCall+=Prepare;else{File.WriteAllText(Path.Combine(Output,"DONE.txt"),"Damage hint font group actually measured; "+Application.unityVersion);if(Application.isBatchMode)EditorApplication.Exit(0);}
 }catch(Exception e){Fail(e);}}
 static void Fail(Exception e){Directory.CreateDirectory(Output);File.WriteAllText(Path.Combine(Output,"ERROR.txt"),e.ToString());Debug.LogException(e);if(Application.isBatchMode)EditorApplication.Exit(1);}
}
