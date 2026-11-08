using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

// PREPARED OFFLINE. Sampling has not been run or compiled in Unity here.
public static class TextRolesProbe {
 [Serializable] public class TextRequest {public string id,text,kind,sourceRichText,anchor;public float lineSpacingOverride;public bool capture;}
 [Serializable] public class Role {public string id,fontPath,characters,importEvidence;public int requestSize,importSize,characterSpacing,characterPadding,fontRenderingMode,ascentCalculationMode;public float lineSpacing;public bool importSettingsVerified,legacyBounds,roundAdvance;public string[] fontNames;public TextRequest[] texts;}
 [Serializable] public class Request {public string status,expectedUnityVersion,fontStyle,anchor,alignment;public Role[] roles;}
 [Serializable] public class Glyph {public string character;public int codepoint,advance,minX,maxX,minY,maxY,glyphWidth,glyphHeight;public bool available,isWhitespace;public Vector2 uvBottomLeft,uvBottomRight,uvTopLeft,uvTopRight;}
 [Serializable] public class TextResult {public string id,text,kind,anchor,alignment,meshStatus,screenshot;public float characterSize,lineSpacing;public int fontSize;public Bounds rendererLocalBounds,rendererWorldBounds;public Vector3 cameraPosition;public Quaternion cameraRotation;public float cameraOrthographicSize,cameraAspect;public int imageWidth,imageHeight;}
 [Serializable] public class RoleResult {public string status,role,fontPath,fontSha256,importSettingsJson,unityVersion,graphicsDevice,graphicsBackend,requestedCharacters,missingCharacters,notes;public int requestSize,atlasWidth,atlasHeight;public float fontAscent,fontLineHeight;public List<Glyph> glyphs=new List<Glyph>();public List<TextResult> texts=new List<TextResult>();}
 static Request request;static int roleIndex;static Role current;static Font font;static RoleResult result;static List<GameObject> objects=new List<GameObject>();
 static string Output {get {var a=Environment.GetCommandLineArgs();int n=Array.IndexOf(a,"-probeOutput");return n>=0&&n+1<a.Length?Path.GetFullPath(a[n+1]):Path.GetFullPath("ProbeOutput");}}
 [MenuItem("Tools/Sample Original Text Roles")]
 public static void Run(){try{
  Directory.CreateDirectory(Output);
  request=JsonUtility.FromJson<Request>(File.ReadAllText("Assets/Probe/request.json"));
  if(request.roles.Any(r=>!r.importSettingsVerified))throw new Exception("Import settings evidence pending: refusing to guess. Complete verified request.json first.");
  if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null)throw new Exception("Needs native graphics device; do not pass -nographics.");
  File.Copy("Assets/Probe/request.json",Path.Combine(Output,"request.actual.json"),true);
  roleIndex=0;PrepareRole();
 }catch(Exception e){Fail(e);}}
 static void SetRequired(SerializedObject so,string field,int value){var p=so.FindProperty(field);if(p==null)throw new Exception("Required import setting missing: "+field);p.intValue=value;}
 static void SetRequired(SerializedObject so,string field,bool value){var p=so.FindProperty(field);if(p==null)throw new Exception("Required import setting missing: "+field);p.boolValue=value;}
 static void PrepareRole(){try{
  current=request.roles[roleIndex];AssetDatabase.ImportAsset(current.fontPath,ImportAssetOptions.ForceSynchronousImport);
  var imp=(TrueTypeFontImporter)AssetImporter.GetAtPath(current.fontPath);
  imp.fontSize=current.importSize;imp.fontTextureCase=FontTextureCase.Dynamic;imp.characterSpacing=current.characterSpacing;imp.characterPadding=current.characterPadding;imp.includeFontData=true;imp.fontRenderingMode=(FontRenderingMode)current.fontRenderingMode;imp.shouldRoundAdvanceValue=current.roundAdvance;imp.fontNames=current.fontNames;imp.fontReferences=new Font[0];
  var so=new SerializedObject(imp);SetRequired(so,"m_UseLegacyBoundsCalculation",current.legacyBounds);if(current.ascentCalculationMode>=0)SetRequired(so,"m_AscentCalculationMode",current.ascentCalculationMode);so.ApplyModifiedPropertiesWithoutUndo();imp.SaveAndReimport();font=AssetDatabase.LoadAssetAtPath<Font>(current.fontPath);
  result=new RoleResult{status="pending",role=current.id,fontPath=current.fontPath,requestSize=current.requestSize,importSettingsJson=EditorJsonUtility.ToJson(imp,true),unityVersion=Application.unityVersion,graphicsDevice=SystemInfo.graphicsDeviceName,graphicsBackend=SystemInfo.graphicsDeviceType.ToString(),fontAscent=font.ascent,fontLineHeight=font.lineHeight,requestedCharacters=current.characters,notes="Native Unity exploratory Font/TextMesh only; no original game screenshot or UberText. Every Font is separate; no atlas UV reuse across roles. All FontStyle.Normal/richText=false, including bold-material diagnostic runs. AscentCalculationMode is unknown in original metadata and not overridden; actual importer value exported. Source fallback references not reconstructed; primary-font candidate isolated with empty refs. Original bold8tap shader is NOT Unity FontStyle.Bold or default rich-text <b>. Whitespace can have zero ink or unavailable CharacterInfo; not a visible-glyph failure. MeshFilter absent means inaccessible generated mesh, never a claim of zero geometry."};
  using(var sha=System.Security.Cryptography.SHA256.Create())result.fontSha256=BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(current.fontPath))).Replace("-","").ToLowerInvariant();
  foreach(var tr in current.texts){var go=new GameObject(current.id+"_"+tr.id);go.layer=30;objects.Add(go);var tm=go.AddComponent<TextMesh>();tm.font=font;tm.fontSize=current.requestSize;tm.fontStyle=FontStyle.Normal;tm.characterSize=1;tm.anchor=String.IsNullOrEmpty(tr.anchor)?TextAnchor.MiddleCenter:(TextAnchor)Enum.Parse(typeof(TextAnchor),tr.anchor);tm.alignment=TextAlignment.Center;tm.lineSpacing=tr.lineSpacingOverride>0?tr.lineSpacingOverride:current.lineSpacing;tm.richText=false;tm.color=Color.white;tm.text=tr.text;go.GetComponent<Renderer>().sharedMaterial=font.material;}
  font.RequestCharactersInTexture(current.characters,current.requestSize,FontStyle.Normal);EditorApplication.QueuePlayerLoopUpdate();EditorApplication.delayCall+=ExportRole;
 }catch(Exception e){Fail(e);}}
 static void ExportRole(){try{
  var dir=Path.Combine(Output,current.id);Directory.CreateDirectory(dir);
  // Final bulk request was completed before this delayed callback. Freeze role sampling order.
  foreach(char c in current.characters.Distinct()){CharacterInfo ci;bool ok=font.GetCharacterInfo(c,out ci,current.requestSize,FontStyle.Normal);result.glyphs.Add(new Glyph{character=c.ToString(),codepoint=c,available=ok,isWhitespace=Char.IsWhiteSpace(c),advance=ci.advance,minX=ci.minX,maxX=ci.maxX,minY=ci.minY,maxY=ci.maxY,glyphWidth=ci.glyphWidth,glyphHeight=ci.glyphHeight,uvBottomLeft=ci.uvBottomLeft,uvBottomRight=ci.uvBottomRight,uvTopLeft=ci.uvTopLeft,uvTopRight=ci.uvTopRight});}
  var atlas=font.material.mainTexture;if(atlas==null)throw new Exception("No atlas");result.atlasWidth=atlas.width;result.atlasHeight=atlas.height;SaveAtlas(atlas,dir);
  for(int n=0;n<objects.Count;n++){
   var go=objects[n];var tm=go.GetComponent<TextMesh>();var rend=go.GetComponent<Renderer>();var tr=current.texts[n];var item=new TextResult{id=tr.id,text=tm.text,kind=tr.kind,anchor=tm.anchor.ToString(),alignment=tm.alignment.ToString(),characterSize=tm.characterSize,lineSpacing=tm.lineSpacing,fontSize=tm.fontSize,rendererLocalBounds=rend.localBounds,rendererWorldBounds=rend.bounds,meshStatus=go.GetComponent<MeshFilter>()==null?"MeshFilter absent; generated vertices unavailable":"MeshFilter exists; not extracted by this probe"};
   if(tr.capture){foreach(var o in objects)o.GetComponent<Renderer>().enabled=false;rend.enabled=true;Capture(go,item,dir);}
   result.texts.Add(item);
  }
  result.missingCharacters=new string(result.glyphs.Where(g=>!g.available&&!g.isWhitespace).Select(g=>(char)g.codepoint).ToArray());result.status=result.missingCharacters.Length==0?"sampled":"partial_missing_visible_glyphs";
  File.WriteAllText(Path.Combine(dir,"glyphs.json"),JsonUtility.ToJson(result,true));File.Copy(current.fontPath,Path.Combine(dir,"font.ttf"),true);File.Copy(current.fontPath+".meta",Path.Combine(dir,"font.ttf.meta"),true);
  foreach(var go in objects)UnityEngine.Object.DestroyImmediate(go);objects.Clear();roleIndex++;
  if(roleIndex<request.roles.Length){EditorApplication.delayCall+=PrepareRole;}else{File.WriteAllText(Path.Combine(Output,"DONE.txt"),"All role exports completed. Actual Unity "+Application.unityVersion+"; inspect each role status. Not original-client fidelity certification.");if(Application.isBatchMode)EditorApplication.Exit(0);}
 }catch(Exception e){Fail(e);}}
 static void SaveAtlas(Texture atlas,string dir){var prev=RenderTexture.active;var rt=RenderTexture.GetTemporary(atlas.width,atlas.height,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);Texture2D tex=null;try{Graphics.Blit(atlas,rt);RenderTexture.active=rt;tex=new Texture2D(atlas.width,atlas.height,TextureFormat.RGBA32,false,true);tex.ReadPixels(new Rect(0,0,atlas.width,atlas.height),0,0);tex.Apply();File.WriteAllBytes(Path.Combine(dir,"atlas_rgba.png"),tex.EncodeToPNG());var px=tex.GetPixels32();for(int n=0;n<px.Length;n++){byte a=px[n].a;px[n]=new Color32(a,a,a,255);}tex.SetPixels32(px);tex.Apply();File.WriteAllBytes(Path.Combine(dir,"atlas_alpha.png"),tex.EncodeToPNG());}finally{RenderTexture.active=prev;RenderTexture.ReleaseTemporary(rt);if(tex!=null)UnityEngine.Object.DestroyImmediate(tex);}}
 static void Capture(GameObject go,TextResult item,string dir){var cg=new GameObject("ProbeCamera");var cam=cg.AddComponent<Camera>();var b=go.GetComponent<Renderer>().bounds;cam.orthographic=true;cam.orthographicSize=Mathf.Max(3,b.extents.y*1.2f,b.extents.x/4*1.2f);cam.aspect=4;cam.transform.position=new Vector3(b.center.x,b.center.y,-10);cam.transform.rotation=Quaternion.identity;cam.nearClipPlane=.1f;cam.farClipPlane=100;cam.clearFlags=CameraClearFlags.SolidColor;cam.backgroundColor=Color.clear;cam.cullingMask=1<<30;cam.allowHDR=false;cam.allowMSAA=false;var rt=new RenderTexture(1024,256,16,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);rt.antiAliasing=1;rt.Create();cam.targetTexture=rt;var old=RenderTexture.active;Texture2D tex=null;try{cam.Render();RenderTexture.active=rt;tex=new Texture2D(1024,256,TextureFormat.RGBA32,false,true);tex.ReadPixels(new Rect(0,0,1024,256),0,0);tex.Apply();item.screenshot=item.id+".png";item.cameraPosition=cam.transform.position;item.cameraRotation=cam.transform.rotation;item.cameraOrthographicSize=cam.orthographicSize;item.cameraAspect=cam.aspect;item.imageWidth=1024;item.imageHeight=256;File.WriteAllBytes(Path.Combine(dir,item.screenshot),tex.EncodeToPNG());}finally{RenderTexture.active=old;cam.targetTexture=null;rt.Release();UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(cg);if(tex!=null)UnityEngine.Object.DestroyImmediate(tex);}}
 static void Fail(Exception e){Directory.CreateDirectory(Output);File.WriteAllText(Path.Combine(Output,"ERROR.txt"),e.ToString());Debug.LogException(e);if(Application.isBatchMode)EditorApplication.Exit(1);}
}
