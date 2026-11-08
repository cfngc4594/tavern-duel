using System;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
public static class ShaderTagCaseProbe {
 [Serializable] class Result {
  public string unityVersion,graphicsBackend,graphicsDevice,firstInput,secondInput,firstName,secondName;
  public int firstHash,secondHash;
  public bool operatorEqual,operatorNotEqual,typedEquals,objectEquals;
 }
 static string Output {get{var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,"-probeOutput");return i>=0&&i+1<a.Length?Path.GetFullPath(a[i+1]):Path.GetFullPath("ShaderTagCaseOutput");}}
 public static void Run(){try{
  Directory.CreateDirectory(Output);
  var a=new ShaderTagId("SRPDEFAULTUNLIT");var b=new ShaderTagId("SRPDefaultUnlit");
  var result=new Result{unityVersion=Application.unityVersion,graphicsBackend=SystemInfo.graphicsDeviceType.ToString(),graphicsDevice=SystemInfo.graphicsDeviceName,firstInput="SRPDEFAULTUNLIT",secondInput="SRPDefaultUnlit",firstName=a.name,secondName=b.name,firstHash=a.GetHashCode(),secondHash=b.GetHashCode(),operatorEqual=a==b,operatorNotEqual=a!=b,typedEquals=a.Equals(b),objectEquals=((object)a).Equals((object)b)};
  string json=JsonUtility.ToJson(result,true);File.WriteAllText(Path.Combine(Output,"shader-tag-case.json"),json);Debug.Log("ShaderTagId actual runtime comparison: "+json);if(Application.isBatchMode)EditorApplication.Exit(0);
 }catch(Exception e){Directory.CreateDirectory(Output);File.WriteAllText(Path.Combine(Output,"ERROR.txt"),e.ToString());Debug.LogException(e);if(Application.isBatchMode)EditorApplication.Exit(1);}}
}
