# Run only authorized privacy-protected graphics tests. Never switches desktops.
# A successful process exit is not a pixel/privacy or performance validation.
# Keep the same feature-gated PrivacyTestGuard used by the tested build.
param([string]$Base,[string]$Exe,[string]$Arguments,[string]$Log,[int]$TimeoutSeconds=240)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @"
using System;
using System.Text;
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
 $result=[PrivateRenderDesktop]::WaitForSingleObject($pi.hProcess,$TimeoutSeconds*1000)
 if($result -eq 258){[void][PrivateRenderDesktop]::TerminateProcess($pi.hProcess,124);[void][PrivateRenderDesktop]::WaitForSingleObject($pi.hProcess,5000);throw 'Test timed out. Only the created test process was terminated.'}
 if($result -ne 0){throw ('WaitForSingleObject failed='+$result)}
 $code=[uint32]0
 if(-not [PrivateRenderDesktop]::GetExitCodeProcess($pi.hProcess,[ref]$code)){throw 'Unable to read test exit code.'}
 Write-Output ('TEST_EXIT_CODE='+$code)
 Write-Output ('ACTIVE_DESKTOP_AFTER='+[PrivateRenderDesktop]::ActiveDesktop())
 if(Test-Path -LiteralPath $log){Write-Output ("LOG="+$log)}
 if($code -ne 0){throw ('Isolated test failed with exit code '+$code)}
} finally {
 if($pi.hThread -ne [IntPtr]::Zero){[void][PrivateRenderDesktop]::CloseHandle($pi.hThread)}
 if($pi.hProcess -ne [IntPtr]::Zero){[void][PrivateRenderDesktop]::CloseHandle($pi.hProcess)}
 [void][PrivateRenderDesktop]::CloseDesktop($desktop)
}