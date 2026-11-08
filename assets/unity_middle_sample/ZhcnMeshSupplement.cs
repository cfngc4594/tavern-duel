using System;
using System.IO;
using System.Collections.Generic;
using UnityEngine;

public static class ZhcnMeshSupplement {
 [Serializable] class Entry {
  public string text,anchor,alignment,fontStyle,meshStatus;
  public bool meshFilterPresent,sharedMeshPresent,rendererPresent;
  public float characterSize,lineSpacing,offsetZ,tabSize;
  public int fontSize;
  public bool richText;
  public Vector3 localPosition,localScale;
  public Quaternion localRotation;
  public Bounds rendererWorldBounds,rendererLocalBounds,meshBounds;
  public Vector3[] vertices;
  public Vector2[] uv;
  public int[] triangles;
  public string screenshot; public Vector3 cameraPosition; public Quaternion cameraRotation; public float cameraOrthographicSize,cameraNear,cameraFar; public int imageWidth,imageHeight;
 }
 [Serializable] class Result {
  public string unityVersion,graphicsDevice,graphicsBackend,notes;
  public List<Entry> texts=new List<Entry>();
 }
 public static void Export(List<GameObject> objects,string output) {
  var result=new Result{unityVersion=Application.unityVersion,graphicsDevice=SystemInfo.graphicsDeviceName,graphicsBackend=SystemInfo.graphicsDeviceType.ToString(),notes="Actual TextMesh component inspection after final character request. No generated or inferred quads. Null arrays mean no accessible sharedMesh. Renderer bounds are diagnostic geometry, not a recovered original Hearthstone layout. Diagnostic screenshots use a new orthographic camera, not a recovered original game camera. RTT 1024x256 ARGB32 Linear depth16 MSAA1; transparent clear; default TextMesh material and white vertex color, orthographicSize3, aspect4, near0.1 far100, layer30, one renderer enabled at a time."};
  foreach(var go in objects) {
   var tm=go.GetComponent<TextMesh>();
   if(tm.text!="冰风雪人"&&tm.text!="吸取生命")continue;
   var filter=go.GetComponent<MeshFilter>();var mesh=filter==null?null:filter.sharedMesh;var renderer=go.GetComponent<Renderer>();var tr=go.transform;
   var entry=new Entry{text=tm.text,anchor=tm.anchor.ToString(),alignment=tm.alignment.ToString(),fontStyle=tm.fontStyle.ToString(),fontSize=tm.fontSize,characterSize=tm.characterSize,lineSpacing=tm.lineSpacing,offsetZ=tm.offsetZ,tabSize=tm.tabSize,richText=tm.richText,localPosition=tr.localPosition,localScale=tr.localScale,localRotation=tr.localRotation,meshFilterPresent=filter!=null,sharedMeshPresent=mesh!=null,rendererPresent=renderer!=null,meshStatus=filter==null?"MeshFilter absent":mesh==null?"MeshFilter.sharedMesh null":"actual MeshFilter.sharedMesh exported"};
   if(renderer!=null){entry.rendererWorldBounds=renderer.bounds;entry.rendererLocalBounds=renderer.localBounds;}
   if(mesh!=null){entry.vertices=mesh.vertices;entry.uv=mesh.uv;entry.triangles=mesh.triangles;entry.meshBounds=mesh.bounds;}
   foreach(var other in objects)other.GetComponent<Renderer>().enabled=other==go;
   go.layer=30;
   var cameraObject=new GameObject("ProbeDiagnosticCamera");var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.orthographicSize=3;camera.aspect=4;camera.nearClipPlane=0.1f;camera.farClipPlane=100;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.clear;camera.cullingMask=1<<30;camera.allowHDR=false;camera.allowMSAA=false;camera.transform.position=new Vector3(renderer.bounds.center.x,renderer.bounds.center.y,-10);
   var rt=new RenderTexture(1024,256,16,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Linear);rt.antiAliasing=1;var previous=RenderTexture.active;Texture2D image=null;
   try{camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image=new Texture2D(1024,256,TextureFormat.RGBA32,false,true);image.ReadPixels(new Rect(0,0,1024,256),0,0);image.Apply();entry.screenshot=tm.text=="冰风雪人"?"textmesh-middlecenter-title-1.png":"textmesh-middlecenter-title-2.png";File.WriteAllBytes(Path.Combine(output,entry.screenshot),image.EncodeToPNG());entry.cameraPosition=camera.transform.position;entry.cameraRotation=camera.transform.rotation;entry.cameraOrthographicSize=camera.orthographicSize;entry.cameraNear=camera.nearClipPlane;entry.cameraFar=camera.farClipPlane;entry.imageWidth=1024;entry.imageHeight=256;}
   finally{camera.targetTexture=null;RenderTexture.active=previous;rt.Release();UnityEngine.Object.DestroyImmediate(rt);if(image!=null)UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(cameraObject);}
   result.texts.Add(entry);
  }
  File.WriteAllText(Path.Combine(output,"textmesh-supplement.json"),JsonUtility.ToJson(result,true));
 }
}
