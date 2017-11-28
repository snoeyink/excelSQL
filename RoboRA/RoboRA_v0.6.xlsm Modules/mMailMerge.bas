Attribute VB_Name = "mMailMerge"
Option Explicit

 Sub flet1()
'
' flet1 Makro
' 1) Merges active record and saves the resulting document named by the datafield     FileName"
' 2) Closes the resulting document, and (assuming that we return to the template)
' 3) advances to the next record in the datasource
'
'S�ren Francis 6/7-2013

    Dim DokName  As String   'ADDED CODE

    With ActiveDocument.MailMerge
        .Destination = wdSendToNewDocument
        .SuppressBlankLines = True
        With .DataSource
            .FirstRecord = ActiveDocument.MailMerge.DataSource.ActiveRecord
            .LastRecord = ActiveDocument.MailMerge.DataSource.ActiveRecord
' Remember the wanted documentname
           DokName = .DataFields("FileName").Value         ' ADDED CODE
        End With

' Merge the active record
        .Execute Pause:=False
    End With

' Save then resulting document. NOTICE MODIFIED filename
    ActiveDocument.SaveAs2 Filename:="C:\Temp\" + DokName + ".docx", FileFormat:= _
        wdFormatXMLDocument, LockComments:=False, Password:="", AddToRecentFiles _
        :=True, WritePassword:="", ReadOnlyRecommended:=False, EmbedTrueTypeFonts _
        :=False, SaveNativePictureFormat:=False, SaveFormsData:=False, _
        SaveAsAOCELetter:=False

' Close the resulting document
    ActiveWindow.Close

' Now, back in the template document, advance to next record
    ActiveDocument.MailMerge.DataSource.ActiveRecord = wdNextRecord
End Sub


Sub MakeIndicatedRAs()
'derived from macro recording with assistance from several stackoverflow posts
'Uses RAtemplate column to decide action and RA template
'blank = ignore this one
'Awd = Award: refresh budget page?
'Std = Standard decline --  automatically stuff to eJacket

 Dim i, t, nRA, nRAtypes As Integer
 Dim wdApp, wdDoc As Object
 Dim strWordDoc As Variant
 Dim strThisWorkbook, strOutputPath, strFilename, strRAtemplate, strRAoutput, dirRAtemplate, dirRAoutput As String
 Dim prop_id As String
 Dim autoDeclineQ, hasAuto As Boolean
 Dim IE As InternetExplorerMedium
 Dim PT As PivotTable


strThisWorkbook = ThisWorkbook.FullName
dirRAtemplate = Range("dirRAtemplate").Value
If Right(dirRAtemplate, 1) <> Application.pathSeparator Then dirRAtemplate = dirRAtemplate & Application.pathSeparator
dirRAoutput = Range("dirRAoutput").Value
If Right(dirRAoutput, 1) <> Application.pathSeparator Then dirRAoutput = dirRAoutput & Application.pathSeparator
 
 'check that templates exist for all actionable items.
 'if any action is upload, check that eJ running.

    For Each PT In Advanced.PivotTables ' find templatesUsed pivot table and refresh
    On Error Resume Next
    If PT.Name = "templatesUsed" Then Exit For
    Next
    PT.RefreshTable
    If Err.Number <> 0 Then
      MsgBox "Can't refresh pivot table " & PT.Name & " on Advanced tab."
      GoTo ErrHandler:
    End If
    On Error GoTo 0

nRAtypes = PT.RowRange.count - 2 ' omit header and total.  For t = 2 To .count - 1
nRA = 0
hasAuto = (LCase$(Left$(Range("autoAllTemplates").Value, 1)) = "y") 'fix
With Range("AllRACandidatesTable[RAtemplate]")
 For i = 1 To .Rows.count  ' quick check
  strRAtemplate = Application.Trim(.Cells(i, 1))
  If Len(strRAtemplate) > 8 Then
    nRA = nRA + 1 ' we have an RA to do
    If Left$(strRAtemplate, 3) = "Std" Then hasAuto = True ' there is an Std (Auto) decline
  End If
 Next i
End With
If nRA = 0 Then
    MsgBox ("Please select RAtemplates from dropdown to indicate which RAs to prepare. If dropdown in the RAtemplate column is empty, pick or refresh the template folder on the Advanced.")
    GoTo ExitHandler:
End If
    
If hasAuto Then Set IE = openEJacket()
    
On Error Resume Next ' start Word  'JSS mac version?
Set wdApp = GetObject(, "Word.Application")
If wdApp Is Nothing Then
    Set wdApp = CreateObject("Word.Application")
End If
On Error GoTo 0
 
 

For t = 2 To PT.RowRange.count - 1
strRAtemplate = Application.Trim(PT.RowRange.Cells(t, 1))
 If Len(strRAtemplate) > 2 And strRAtemplate <> "(blank)" Then ' we have an RA template
   Set wdDoc = wdApp.Documents.Open(dirRAtemplate & strRAtemplate)

    Do While wdDoc Is Nothing ' NOT TESTED
      If (MsgBox("can't find Word template " & dirRAtemplate & strRAtemplate & vbNewLine & " Open via dialog?", vbOKCancel) <> vbOK) Then GoTo ExitHandler:
      Dim fd As FileDialog 'File Picker dialog box.
      Set fd = Application.FileDialog(msoFileDialogFilePicker)
        With fd
           .AllowMultiSelect = False
           If .Show <> -1 Then GoTo ExitHandler: 'Show File Picker; abort on cancel
           strWordDoc = .SelectedItems(1)
           Set wdDoc = wdApp.Documents.Open(strWordDoc)
       End With
       Set fd = Nothing
    Loop
    On Error GoTo 0
    
   autoDeclineQ = (LCase$(Left$(Range("autoAllTemplates").Value, 1)) = "y") Or (Left$(strRAtemplate, 3) = "Std")
    wdDoc.Activate
    wdApp.Visible = True
    
' Sort by RecRkMin because our dummy line for formatting must come first.
   With ThisWorkbook.Worksheets("AllRACandidates").ListObjects("AllRACandidatesTable").Sort
        .SortFields.Clear
        .SortFields.Add Key:=Range("AllRACandidatesTable[[#All],[RecRkMin]]"), SortOn:=xlSortOnValues, Order:=xlAscending, DataOption:=xlSortTextAsNumbers
        .Header = xlYes
        .MatchCase = False
        .Orientation = xlTopToBottom
        .SortMethod = xlPinYin
        .Apply
    End With
        
    With Range("AllRACandidatesTable[RAtemplate]") ' need RAfname as next column!!!
      For i = 1 To .Rows.count ' do the RAs
       If strRAtemplate = Application.Trim(.Cells(i, 1)) Then ' we have an RA to do
        strRAoutput = dirRAoutput & Application.Trim(.Cells(i, 2)) & ".docm" ' make output file name
    '    Application.ScreenUpdating = False
    '    Application.DisplayAlerts = False
    'Connection:= "Provider=Microsoft.ACE.OLEDB.12.0;User ID=Admin;Data Source=C:\Users\Jack Snoeyink\Desktop\tmp.xlsm';Mode=Read;Extended Properties=""HDR=YES;IMEX=1;"";Jet OLEDB:System database="""";Jet OLEDB:Registry Path="""";Jet OLEDB:Engine Type=3"
       With wdDoc.MailMerge
           .MainDocumentType = wdFormLetters
          
          .OpenDataSource Name:=strThisWorkbook, _
              LinkToSource:=False, AddToRecentFiles:=False, Revert:=False, Format:=wdOpenFormatAuto, _
              Connection:="Data Source='" & strThisWorkbook & "';Mode=Read", _
              SQLStatement:="SELECT * FROM `AllRACandidates$`"
     
          .Destination = wdSendToNewDocument
          .SuppressBlankLines = True
            
           With .DataSource
             .FirstRecord = i
             .LastRecord = i
           End With 'data source
          .Execute Pause:=True 'False
          
          If autoDeclineQ Then
            Dim RAtext As String
    
            wdApp.ActiveDocument.ActiveWindow.Selection.WholeStory
            RAtext = FixIPSText(StripDoubleBrackets(wdApp.ActiveDocument.ActiveWindow.Selection.Text))
            wdApp.ActiveDocument.ActiveWindow.Selection.Collapse
            prop_id = Trim(Range("AllRACandidatesTable[[prop_id0]]").Cells(i, 1).Value)
            
           Call autoPasteRA(IE, prop_id, RAtext)
           wdApp.ActiveDocument.ReadOnlyRecommended = True
          End If
          '.AttachedTemplate = "RAaddin.dotm" 'JSS what if this is on a different computer?
          wdApp.ActiveDocument.SaveAs2 Filename:=strRAoutput, FileFormat:=wdFormatXMLDocumentMacroEnabled, LockComments:=False, Password:="", AddToRecentFiles _
            :=True, WritePassword:="", ReadOnlyRecommended:=False, EmbedTrueTypeFonts _
            :=False, SaveNativePictureFormat:=False, SaveFormsData:=False, _
            SaveAsAOCELetter:=False
          '.SaveAs Filename:=strRAoutput, FileFormat:=wdFormatXMLDocumentMacroEnabled, _
           '        AddToRecentFiles:=True, ReadOnlyRecommended:=False
          wdApp.ActiveDocument.Close SaveChanges:=wdSaveChanges
          End With 'document
          
       ' ActiveWindow.Close
      End If ' done mailmerge
     Next i
     End With 'table range
  End If
   If Not (wdDoc Is Nothing) Then
     wdDoc.Close SaveChanges:=wdDoNotSaveChanges
     Set wdDoc = Nothing
   End If
 Next t

ExitHandler:
If hasAuto Then Call closeEJacket(IE)
If Not (wdDoc Is Nothing) Then
   wdDoc.Close SaveChanges:=wdDoNotSaveChanges
   Set wdDoc = Nothing
End If
Exit Sub

ErrHandler:
  MsgBox ("Error in MakeIndicatedRAs: " & Err.Number & ":" & Err.Description)
  Resume ExitHandler
End Sub

Sub makeProjText()
'derived from macro recording with assistance from several stackoverflow posts

 Dim wdApp, wdDoc As Object
 Dim strWordDoc, strThisWorkbook, strPDFOutputName As String
 
 strThisWorkbook = ThisWorkbook.FullName
 strWordDoc = ThisWorkbook.path & "\RAhelpTemplate.docx"
 strPDFOutputName = ThisWorkbook.path & "\RAhelp" & Format(Now(), "-yy_mm_dd-hh_mm")

On Error Resume Next
Set wdApp = GetObject(, "Word.Application")
If wdApp Is Nothing Then
    Set wdApp = CreateObject("Word.Application")
End If
On Error GoTo 0
 
'    Application.ScreenUpdating = False
'    Application.DisplayAlerts = False

 Set wdDoc = wdApp.Documents.Open(strWordDoc)
 wdDoc.Activate
 wdApp.Visible = True

'Connection:= "Provider=Microsoft.ACE.OLEDB.12.0;User ID=Admin;Data Source=C:\Users\Jack Snoeyink\Desktop\tmp.xlsm';Mode=Read;Extended Properties=""HDR=YES;IMEX=1;"";Jet OLEDB:System database="""";Jet OLEDB:Registry Path="""";Jet OLEDB:Engine Type=3"
    With wdDoc.MailMerge
       .MainDocumentType = 0 'wdFormLetters, wdOpenFormatAuto
      
      .OpenDataSource Name:=strThisWorkbook, _
          LinkToSource:=False, AddToRecentFiles:=False, Revert:=False, Format:=0, _
          Connection:="Data Source='" & strThisWorkbook & "';Mode=Read" _
          , SQLStatement:="SELECT * FROM `ProjText$`"
 
        .Destination = 0 'wdSendToNewDocument
        .SuppressBlankLines = True
        With .DataSource
            .FirstRecord = 1
            .LastRecord = -16
        End With
        .Execute Pause:=True 'False
    End With
    
    'export format pdf=17, opt for screen=1,wdExportCreateHeadingBookmarks=1
    wdApp.ActiveDocument.ExportAsFixedFormat OutputFileName:=strPDFOutputName, ExportFormat:= _
        17, OpenAfterExport:=True, OptimizeFor:= _
        1, Range:=0, from:=1, To:=1, _
        Item:=0, IncludeDocProps:=True, KeepIRM:=True, _
        CreateBookmarks:=1, DocStructureTags:=True, _
        BitmapMissingFonts:=True, UseISO19005_1:=False
        
 wdApp.ActiveDocument.Close SaveChanges:=0 ' don't save changes
 wdDoc.Close SaveChanges:=0

End Sub