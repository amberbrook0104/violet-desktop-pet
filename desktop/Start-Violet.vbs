Option Explicit
Dim shell, files, folder, powershell, command
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
folder = files.GetParentFolderName(WScript.ScriptFullName)
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
command = """" & powershell & """ -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & folder & "\VioletPet.ps1"""
shell.Run command, 0, False
