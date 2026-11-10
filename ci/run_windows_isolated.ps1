# Run only authorized privacy-protected graphics tests. Never switches desktops.
# A successful process exit is not a pixel/privacy or performance validation.
# Keep the same feature-gated PrivacyTestGuard used by the tested build.
param([string]$Base,[string]$Exe,[string]$Arguments,[string]$Log,[int]$TimeoutSeconds=240,[string]$MetricsPath="")
$ErrorActionPreference='Stop'
# Export templates resolve relative log paths against their resource directory,
# not necessarily CreateProcess's working directory. A missing nested directory
# can crash before a useful engine log exists. Resolve/create only output paths.
$Base=(Resolve-Path -LiteralPath $Base).Path
if(-not [IO.Path]::IsPathRooted($Log)){$Log=Join-Path $Base $Log}
$Log=[IO.Path]::GetFullPath($Log)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Log))
if($MetricsPath){
 if(-not [IO.Path]::IsPathRooted($MetricsPath)){$MetricsPath=Join-Path $Base $MetricsPath}
 $MetricsPath=[IO.Path]::GetFullPath($MetricsPath)
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($MetricsPath))
}
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
public static class PrivateRenderDesktop {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct STARTUPINFO { public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle; public uint dwX; public uint dwY; public uint dwXSize; public uint dwYSize; public uint dwXCountChars; public uint dwYCountChars; public uint dwFillAttribute; public uint dwFlags; public ushort wShowWindow; public ushort cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError; }
 [StructLayout(LayoutKind.Sequential)] public struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public uint dwProcessId; public uint dwThreadId; }
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, uint flags, uint access, IntPtr security);
 [DllImport("user32.dll", SetLastError=true)] public static extern bool CloseDesktop(IntPtr desk);
 [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
 [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr GetProcessWindowStation();
 [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr GetThreadDesktop(uint tid);
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool GetUserObjectInformation(IntPtr handle, int index, StringBuilder data, uint length, out uint needed);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool CreateProcess(string application, StringBuilder command, IntPtr processSecurity, IntPtr threadSecurity, bool inherit, uint flags, IntPtr environment, string directory, ref STARTUPINFO startup, out PROCESS_INFORMATION process);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetExitCodeProcess(IntPtr process, out uint code);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool TerminateProcess(IntPtr process, uint code);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr handle);
 [StructLayout(LayoutKind.Sequential)] public struct PROCESS_MEMORY_COUNTERS_EX { public uint cb, PageFaultCount; public UIntPtr PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage, QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage, PagefileUsage, PeakPagefileUsage, PrivateUsage; }
 [DllImport("psapi.dll", SetLastError=true)] public static extern bool GetProcessMemoryInfo(IntPtr process, out PROCESS_MEMORY_COUNTERS_EX counters, uint size);
 public class MemorySample { public long elapsed_ms; public ulong working_set_bytes, peak_working_set_bytes, private_bytes, commit_bytes, peak_commit_bytes; }
 public class ProcessMeasurements { public uint wait_result; public long wait_wall_ms; public int sample_interval_ms=250; public int failed_memory_reads; public List<MemorySample> samples=new List<MemorySample>(); }
 public static ProcessMeasurements WaitAndMeasure(IntPtr process, int timeoutSeconds) {
  var result=new ProcessMeasurements(); var clock=Stopwatch.StartNew();
  while (true) {
   PROCESS_MEMORY_COUNTERS_EX memory;
   if(GetProcessMemoryInfo(process,out memory,(uint)Marshal.SizeOf(typeof(PROCESS_MEMORY_COUNTERS_EX)))) result.samples.Add(new MemorySample {elapsed_ms=clock.ElapsedMilliseconds, working_set_bytes=memory.WorkingSetSize.ToUInt64(),peak_working_set_bytes=memory.PeakWorkingSetSize.ToUInt64(),private_bytes=memory.PrivateUsage.ToUInt64(),commit_bytes=memory.PagefileUsage.ToUInt64(),peak_commit_bytes=memory.PeakPagefileUsage.ToUInt64()});
   else result.failed_memory_reads++;
   var remaining=timeoutSeconds*1000-clock.ElapsedMilliseconds;
   if(remaining<=0) {result.wait_result=258; break;}
   result.wait_result=WaitForSingleObject(process,(uint)Math.Min(250,remaining));
   if(result.wait_result!=258) break;
  }
  result.wait_wall_ms=clock.ElapsedMilliseconds; return result;
 }
 public static string ObjectName(IntPtr h) { var s=new StringBuilder(256); uint n; if (!GetUserObjectInformation(h,2,s,512,out n)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); return s.ToString(); }
 public static string ActiveDesktop() { var h=OpenInputDesktop(0,false,1); if(h==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); try {return ObjectName(h);} finally {CloseDesktop(h);} }
}
"@


$before=[PrivateRenderDesktop]::ActiveDesktop()
$station=[PrivateRenderDesktop]::ObjectName([PrivateRenderDesktop]::GetProcessWindowStation())
$deskName='tavern_benchmark_'+[Guid]::NewGuid().ToString('N')
$desktop=[PrivateRenderDesktop]::CreateDesktop($deskName,[IntPtr]::Zero,[IntPtr]::Zero,0,0xC7,[IntPtr]::Zero)
if($desktop -eq [IntPtr]::Zero){throw ('CreateDesktop denied/error='+[Runtime.InteropServices.Marshal]::GetLastWin32Error()+'. No test started.')}
$pi=[PrivateRenderDesktop+PROCESS_INFORMATION]::new()
$started=$false
$launchClock=[Diagnostics.Stopwatch]::StartNew()
try {
 $si=[PrivateRenderDesktop+STARTUPINFO]::new()
 $si.cb=[Runtime.InteropServices.Marshal]::SizeOf($si)
 $si.lpDesktop=$station+'\'+$deskName
 $si.dwFlags=1
 $si.wShowWindow=0
 $command=[Text.StringBuilder]::new(('"{0}" --log-file "{2}" {1}' -f $Exe,$Arguments,$Log))
 $started=[PrivateRenderDesktop]::CreateProcess($exe,$command,[IntPtr]::Zero,[IntPtr]::Zero,$false,0x08000000,[IntPtr]::Zero,$Base,[ref]$si,[ref]$pi)
 if(-not $started){throw ('CreateProcess denied/error='+[Runtime.InteropServices.Marshal]::GetLastWin32Error()+'. No test started.')}
 Write-Output ('TEST_PID='+$pi.dwProcessId)
 Write-Output ('TARGET_DESKTOP='+$si.lpDesktop)
 Write-Output ('ACTIVE_DESKTOP_BEFORE='+$before)
 $metrics=$null
 if($MetricsPath) {
  $metrics=[PrivateRenderDesktop]::WaitAndMeasure($pi.hProcess,$TimeoutSeconds)
  $result=$metrics.wait_result
 } else { $result=[PrivateRenderDesktop]::WaitForSingleObject($pi.hProcess,$TimeoutSeconds*1000) }
 $launchClock.Stop()
 if($result -eq 258){[void][PrivateRenderDesktop]::TerminateProcess($pi.hProcess,124);[void][PrivateRenderDesktop]::WaitForSingleObject($pi.hProcess,5000);throw 'Test timed out. Only the created test process was terminated.'}
 if($result -ne 0){throw ('WaitForSingleObject failed='+$result)}
 $code=[uint32]0
 if(-not [PrivateRenderDesktop]::GetExitCodeProcess($pi.hProcess,[ref]$code)){throw 'Unable to read test exit code.'}
 if($MetricsPath) {
  $record=@{schema=1;process_id=$pi.dwProcessId;process_wall_ms=$launchClock.ElapsedMilliseconds;exit_code=$code;sample_interval_ms=$metrics.sample_interval_ms;failed_memory_reads=$metrics.failed_memory_reads;samples=@($metrics.samples.ToArray());scope='Own target process from CreateProcess to exit; 250ms memory samples. Peak counters reflect lifetime peaks observed by polling; the final interval and short private-memory peaks can be missed. No unrelated processes are read.'}
  $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $MetricsPath -Encoding utf8
  Write-Output ('PROCESS_METRICS='+$MetricsPath)
 }
 Write-Output ('TEST_EXIT_CODE='+$code)
 Write-Output ('ACTIVE_DESKTOP_AFTER='+[PrivateRenderDesktop]::ActiveDesktop())
 if(Test-Path -LiteralPath $log){Write-Output ("LOG="+$log)}
 if($code -ne 0){throw ('Isolated test failed with exit code '+$code)}
} finally {
 if($pi.hThread -ne [IntPtr]::Zero){[void][PrivateRenderDesktop]::CloseHandle($pi.hThread)}
 if($pi.hProcess -ne [IntPtr]::Zero){[void][PrivateRenderDesktop]::CloseHandle($pi.hProcess)}
 [void][PrivateRenderDesktop]::CloseDesktop($desktop)
}
