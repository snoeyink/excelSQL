Attribute VB_Name = "mRoboRA"
Option Explicit
' Utility routines specific to RoboRA
Public Function SummarizeQuestMarks(abstr As String) As String
' Summarize ? from string that may have been converted from quotes, dashes, or other special characters.
Dim i As Long
Dim s As String
s = " "
i = InStrRev(abstr, "?")
Do While i > 0
  If i < 4 Then
    s = VBA.Mid$(abstr, i, 5) & "|" & s
    Exit Do
  ElseIf Not VBA.Mid$(abstr, i - 1, 3) Like "[a-zA-Z][?][ '""]" Then
    i = i - 3
    s = VBA.Mid$(abstr, i, 8) & "|" & s
  End If
  i = InStrRev(abstr, "?", i - 1)
Loop
SummarizeQuestMarks = s
End Function

Private Sub test_SummarizeQuestMarks()
Debug.Print SummarizeQuestMarks("?Testing? Is this OK? ""And this?"" This houldn't be??  ?Done?.")
End Sub

Function autoPasteRA(IE As InternetExplorerMedium, prop_id As String, RA As String) As String
' stuff RA into text box using mAutocoder functions
Dim i As Integer, j As Integer
Dim overwriteQ As Variant

overwriteQ = RoboRA.Range("overwrite_option").Value
If (Len(prop_id) <> 7) Then ' Probably have a prop_id; go to Jacket
    autoPasteRA = prop_id & " not a prop_id" & vbNewLine
    Exit Function
End If

IE.Navigate ("https://www.ejacket.nsf.gov/ej/showProposal.do?Continue=Y&ID=" & prop_id)
Call myWait(IE)
IE.Navigate ("https://www.ejacket.nsf.gov/ej/processReviewAnalysis.do?dispatch=add&uniqId=" & prop_id & VBA.LCase$(VBA.Left$(VBA.Environ$("USERNAME"), 7)))
Call myWait(IE)

If IE.Document.getElementsByName("text")(0) Is Nothing Then
  autoPasteRA = prop_id & " can't visit eJ RA" & vbNewLine
  Exit Function
End If

With IE.Document.getElementsByName("text")(0)
  .Focus
  If (Len(.Value) < 10) Or (overwriteQ = 3) Then
   .Focus
   .Value = RA
  ElseIf (overwriteQ = 2) Then ' ask permission to overwrite
    AppActivate Application.Caption
    DoEvents
    If (MsgBox("OK to overwrite existing RA for " & prop_id & vbNewLine & .Value, vbOKCancel) = vbOK) Then
     .Focus
     .Value = RA
    Else ' permission not granted
      autoPasteRA = prop_id & " not overwritten." & vbNewLine
      Exit Function
    End If
  Else ' never overwrite
    autoPasteRA = prop_id & " has text in RA field." & vbNewLine
    Exit Function
  End If
End With

Call myWait(IE)
If Not IE.Document.getElementsByName("save")(0) Is Nothing Then
  IE.Document.getElementsByName("save")(0).Click
  Call myWait(IE)
  autoPasteRA = ""
Else
  autoPasteRA = prop_id & " can't save eJ RA" & vbNewLine
End If
End Function


Sub List_Templates() ' list RA templates available (used by data validation)
Dim templateName As String
Dim nTemplates As Integer
Dim dirRAtemplate As String
dirRAtemplate = Advanced.Range("dirRAtemplate").Value
If VBA.Right$(dirRAtemplate, 1) <> Application.pathSeparator Then dirRAtemplate = dirRAtemplate & Application.pathSeparator

nTemplates = 0
Application.ScreenUpdating = False
On Error GoTo ErrHandler
With Advanced.ListObjects("AvailableTemplates")
  If Not .DataBodyRange Is Nothing Then .DataBodyRange.Delete
  templateName$ = Dir(dirRAtemplate & "*RAt.docx") ' ensure consistency with messages below
    Do While templateName$ <> ""
      If VBA.Left$(templateName$, 1) <> "~" Then
        .ListRows.Add AlwaysInsert:=True
        nTemplates = nTemplates + 1
        .DataBodyRange(nTemplates, 1) = templateName$
      End If
      templateName$ = Dir
    Loop
End With
Application.ScreenUpdating = True
If nTemplates = 0 Then
  If MsgBox("Did not find any RA templates in " & dirRAtemplate & "; shall I copy the standard templates to that folder?" _
           & vbNewLine & "Note: RA template names must end with RAt.docx; award templates must start with Awd and standard templates (autoloaded) must start with Std", vbOKCancel) = vbOK Then
             Call renewFiles(Range("SharedRAtemplate").Value, Range("dirRAtemplate").Value & "\")
             Call List_Templates
  End If
End If
ExitHandler:
Exit Sub
ErrHandler:
Application.ScreenUpdating = True
MsgBox ("Error " & Err.Number & ":" & Err.Description & vbNewLine & "while trying to list templates.  Ensure template directory, " & Range("dirRAtemplate").Value & ", is accessible.")
Resume ExitHandler
End Sub

Sub Picker_dirRAtemplate()
Dim folderName As String
folderName = FolderPicker("Choose input folder containing RA templates *RAt.docx", Range("dirRAtemplate").Value)
If folderName <> "" Then Range("dirRAtemplate").Value = folderName
Call List_Templates
End Sub

Sub Picker_dirRAoutput()
Dim folderName As String
folderName = FolderPicker("Choose output folder for populated RA drafts (.docm)", Range("dirRAoutput").Value)
If folderName <> "" Then Range("dirRAoutput").Value = folderName
End Sub


'\\collaboration.inside.nsf.gov@SSL\DavWWWRoot\eng\meritreview\SiteAssets\ENG Tools Websites and Best Practices\RoboRA\RAtemplates\*.docx
Sub CheckRAFolders()
  If Len(Range("SharedRAtemplate").Value) < 2 Then Range("SharedRAtemplate").Value = ThisWorkbook.path & "RAtemplates\*.docx"
'  If Len(Range("dirRAoutput").Value) < 2 Then Call Picker_dirRAoutput
End Sub



'Sub installMacros()
'Dim pathName As String
'
'On Error GoTo ErrHandler:
''JSS PC vs mac version
'pathName$ = "%appdata%\Microsoft\Word\STARTUP"
'If Dir(pathName$, vbDirectory) = "" Then MkDir (pathName$)
'MsgBox ("copying RAaddin.dotm into " & pathName$)
''JSS copy file RAaddin.dotm and trust it.
'ExitHandler:
'  On Error GoTo 0
'  Exit Sub
'ErrHandler:
'  MsgBox ("Error in Install_Raddin: " & Err.Number & ":" & Err.Description)
'  Resume ExitHandler
'End Sub

