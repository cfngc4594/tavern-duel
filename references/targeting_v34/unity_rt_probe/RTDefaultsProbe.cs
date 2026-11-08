using System;
using System.IO;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
public static class RTDefaultsProbe {
 [Serializable] class Properties {public string stage,wrapMode,wrapModeU,wrapModeV,wrapModeW,filterMode,graphicsFormat,format;public bool useMipMap,autoGenerateMips,sRGB,isCreated;public int antiAliasing,anisoLevel;public float mipMapBias;}
 [Serializable] class Sample {public float u,v;public Color rgba;}
 [Serializable] class Result {public string status,unityVersion,graphicsAPI,graphicsDevice,activeColorSpace,projectColorSpace,notes;public List<Properties> finalRTProperties=new List<Properties>();public List<Sample> finalSamples=new List<Sample>(),temporarySamples=new List<Sample>();}
 static string Output {get{var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,"-probeOutput");return i>=0&&i+1<a.Length?Path.GetFullPath(a[i+1]):Path.GetFullPath("RTDefaultsOutput");}}
 static Properties Inspect(RenderTexture rt,string stage){return new Properties{stage=stage,wrapMode=rt.wrapMode.ToString(),wrapModeU=rt.wrapModeU.ToString(),wrapModeV=rt.wrapModeV.ToString(),wrapModeW=rt.wrapModeW.ToString(),filterMode=rt.filterMode.ToString(),useMipMap=rt.useMipMap,autoGenerateMips=rt.autoGenerateMips,antiAliasing=rt.antiAliasing,graphicsFormat=rt.graphicsFormat.ToString(),format=rt.format.ToString(),sRGB=rt.sRGB,anisoLevel=rt.anisoLevel,mipMapBias=rt.mipMapBias,isCreated=rt.IsCreated()};}
 static RenderTexture CaptureRT(int w,int h){var r=new RenderTexture(w,h,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);r.Create();return r;}
 static List<Sample> Save(RenderTexture rt,string name,bool samples){var old=RenderTexture.active;Texture2D t=null;try{RenderTexture.active=rt;t=new Texture2D(rt.width,rt.height,TextureFormat.RGBA32,false,true);t.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);t.Apply();File.WriteAllBytes(Path.Combine(Output,name+".png"),t.EncodeToPNG());var data=new List<Sample>();if(samples){float[] us={-.25f,.25f,.75f,1.25f};for(int i=0;i<4;i++)data.Add(new Sample{u=us[i],v=.5f,rgba=t.GetPixel(i,0)});}return data;}finally{RenderTexture.active=old;if(t!=null)UnityEngine.Object.DestroyImmediate(t);}}
 public static void Run(){RenderTexture final=null,finalPattern=null,tempPattern=null,finalSamples=null,tempSamples=null;Material pattern=null,sample=null;CommandBuffer cb=null;try{
  Directory.CreateDirectory(Output);if(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Null)throw new Exception("Real graphics device required");
  var ps=AssetDatabase.LoadAssetAtPath<Shader>("Assets/ProbeShaders/RTProbePattern.shader");var ss=AssetDatabase.LoadAssetAtPath<Shader>("Assets/ProbeShaders/RTProbeSample.shader");if(ps==null||ss==null||!ps.isSupported||!ss.isSupported)throw new Exception("Probe shader absent or unsupported");pattern=new Material(ps);sample=new Material(ss);
  var r=new Result{status="measured",unityVersion=Application.unityVersion,graphicsAPI=SystemInfo.graphicsDeviceType.ToString(),graphicsDevice=SystemInfo.graphicsDeviceName,activeColorSpace=QualitySettings.activeColorSpace.ToString(),projectColorSpace=PlayerSettings.colorSpace.ToString(),notes="Final uses exact new RenderTexture(16,4,16,(RenderTextureFormat)16,(RenderTextureReadWrite)0), no properties assigned. Temporary exact six-argument CommandBuffer.GetTemporaryRT(id,16,4,16,FilterMode.Bilinear,(RenderTextureFormat)16); no managed-object property claim, wrap never assigned. Pattern writes red0.2 at left half,red0.8 right half. Edge shader samples u=-0.25,0.25,0.75,1.25,v0.5; middle controls separate color conversion from wrapping. Diagnostic ARGB32 Linear capture targets are separate resources. PNGs RGBA8 readback. Allocation repeated independently only through original requested APIs; no RenderTexture.GetTemporary used."};
  final=new RenderTexture(16,4,16,(RenderTextureFormat)16,(RenderTextureReadWrite)0);r.finalRTProperties.Add(Inspect(final,"after_constructor_before_Create"));if(!final.Create())throw new Exception("Final RT Create returned false");r.finalRTProperties.Add(Inspect(final,"after_Create"));
  finalPattern=CaptureRT(16,4);tempPattern=CaptureRT(16,4);finalSamples=CaptureRT(4,1);tempSamples=CaptureRT(4,1);
  Graphics.Blit(Texture2D.blackTexture,final,pattern);Graphics.Blit(final,finalPattern);Shader.SetGlobalTexture("_ProbeSource",final);Graphics.Blit(Texture2D.blackTexture,finalSamples,sample);r.finalSamples=Save(finalSamples,"final-edge-samples",true);Save(finalPattern,"final-pattern",false);
  int id=Shader.PropertyToID("_ExactSixArgTemporary");cb=new CommandBuffer();cb.name="Exact six-argument RT edge probe";
  cb.GetTemporaryRT(id,16,4,16,FilterMode.Bilinear,(RenderTextureFormat)16);
  cb.Blit(Texture2D.blackTexture,new RenderTargetIdentifier(id),pattern);
  cb.Blit(new RenderTargetIdentifier(id),tempPattern);
  cb.SetGlobalTexture("_ProbeSource",new RenderTargetIdentifier(id));cb.Blit(Texture2D.blackTexture,tempSamples,sample);cb.ReleaseTemporaryRT(id);Graphics.ExecuteCommandBuffer(cb);
  r.temporarySamples=Save(tempSamples,"temporary-edge-samples",true);Save(tempPattern,"temporary-pattern",false);
  File.WriteAllText(Path.Combine(Output,"rt-defaults-edge-samples.json"),JsonUtility.ToJson(r,true));Debug.Log("Exact RT defaults and edge sampling measured: "+JsonUtility.ToJson(r));
 }catch(Exception e){Directory.CreateDirectory(Output);File.WriteAllText(Path.Combine(Output,"ERROR.txt"),e.ToString());Debug.LogException(e);if(Application.isBatchMode)EditorApplication.Exit(1);return;}finally{
  Shader.SetGlobalTexture("_ProbeSource",null);if(cb!=null)cb.Release();foreach(var rt in new[]{final,finalPattern,tempPattern,finalSamples,tempSamples})if(rt!=null){rt.Release();UnityEngine.Object.DestroyImmediate(rt);}if(pattern!=null)UnityEngine.Object.DestroyImmediate(pattern);if(sample!=null)UnityEngine.Object.DestroyImmediate(sample);
 }if(Application.isBatchMode)EditorApplication.Exit(0);}
}
