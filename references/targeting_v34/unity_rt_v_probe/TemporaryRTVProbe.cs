using System;
using System.IO;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
public static class TemporaryRTVProbe {
 [Serializable] class Sample {public float u,v;public Color rgba;}
 [Serializable] class Result {public string status,unityVersion,graphicsAPI,graphicsDevice,activeColorSpace,projectColorSpace,notes;public Color patternBottomPixel,patternTopPixel;public List<Sample> samples=new List<Sample>();}
 static string Output {get{var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,"-probeOutput");return i>=0&&i+1<a.Length?Path.GetFullPath(a[i+1]):Path.GetFullPath("TemporaryRTVOutput");}}
 static Texture2D Read(RenderTexture rt,string filename){var old=RenderTexture.active;try{RenderTexture.active=rt;var t=new Texture2D(rt.width,rt.height,TextureFormat.RGBA32,false,true);t.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);t.Apply();File.WriteAllBytes(Path.Combine(Output,filename),t.EncodeToPNG());return t;}finally{RenderTexture.active=old;}}
 public static void Run(){RenderTexture capture=null,destination=null;Material pattern=null,sample=null;CommandBuffer cb=null;Texture2D p=null,s=null;int exit=0;try{
  Directory.CreateDirectory(Output);if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null)throw new Exception("Native GPU required");
  var ps=AssetDatabase.LoadAssetAtPath<Shader>("Assets/ProbeShaders/RTProbePatternV.shader");var ss=AssetDatabase.LoadAssetAtPath<Shader>("Assets/ProbeShaders/RTProbeSampleV.shader");if(ps==null||ss==null||!ps.isSupported||!ss.isSupported)throw new Exception("Probe shader missing or unsupported");pattern=new Material(ps);sample=new Material(ss);
  capture=new RenderTexture(16,16,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);capture.Create();destination=new RenderTexture(4,1,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);destination.Create();
  int id=Shader.PropertyToID("_ExactSixArgTemporaryV");cb=new CommandBuffer();cb.name="Exact temporary2D V edge measurement";
  cb.GetTemporaryRT(id,16,16,16,FilterMode.Bilinear,(RenderTextureFormat)16);
  cb.Blit(Texture2D.blackTexture,new RenderTargetIdentifier(id),pattern);cb.Blit(new RenderTargetIdentifier(id),capture);cb.SetGlobalTexture("_ProbeSourceV",new RenderTargetIdentifier(id));cb.Blit(Texture2D.blackTexture,destination,sample);cb.ReleaseTemporaryRT(id);Graphics.ExecuteCommandBuffer(cb);
  p=Read(capture,"temporary-v-pattern.png");s=Read(destination,"temporary-v-edge-samples.png");
  var result=new Result{status="measured",unityVersion=Application.unityVersion,graphicsAPI=SystemInfo.graphicsDeviceType.ToString(),graphicsDevice=SystemInfo.graphicsDeviceName,activeColorSpace=QualitySettings.activeColorSpace.ToString(),projectColorSpace=PlayerSettings.colorSpace.ToString(),patternBottomPixel=p.GetPixel(8,2),patternTopPixel=p.GetPixel(8,13),notes="Exact CommandBuffer.GetTemporaryRT(id,16,16,16,FilterMode.Bilinear,(RenderTextureFormat)16); no wrap assigned, no RenderTexture.GetTemporary. Source single red channel R8. Pattern shader red0.2 when UV.y<0.5,red0.8 when UV.y>=0.5. Unity Texture2D.GetPixel origin bottom-left: exported patternBottomPixel=(8,2),patternTopPixel=(8,13). PNG display top row maps to Unity top, bottom row to Unity bottom. Edge output is horizontal four-pixel strip left-to-right v=-0.25,0.25,0.75,1.25, fixed u0.5. Diagnostic capture/destination ARGB32 Linear separate from source. No W sampling or inference."};
  float[] vs={-.25f,.25f,.75f,1.25f};for(int i=0;i<4;i++)result.samples.Add(new Sample{u=.5f,v=vs[i],rgba=s.GetPixel(i,0)});File.WriteAllText(Path.Combine(Output,"temporary-v-edge.json"),JsonUtility.ToJson(result,true));Debug.Log("Temporary2D V actual result: "+JsonUtility.ToJson(result));
 }catch(Exception e){Directory.CreateDirectory(Output);File.WriteAllText(Path.Combine(Output,"ERROR.txt"),e.ToString());Debug.LogException(e);exit=1;}finally{Shader.SetGlobalTexture("_ProbeSourceV",null);if(cb!=null)cb.Release();if(p!=null)UnityEngine.Object.DestroyImmediate(p);if(s!=null)UnityEngine.Object.DestroyImmediate(s);foreach(var rt in new[]{capture,destination})if(rt!=null){rt.Release();UnityEngine.Object.DestroyImmediate(rt);}if(pattern!=null)UnityEngine.Object.DestroyImmediate(pattern);if(sample!=null)UnityEngine.Object.DestroyImmediate(sample);}if(Application.isBatchMode)EditorApplication.Exit(exit);}
}
