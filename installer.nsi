!include "FileFunc.nsh"
!include "TextFunc.nsh"
[% extends "pyapp_msvcrt.nsi" %]

[% block modernui %]
  ; let the user review all changes being made to the system first
  !define MUI_FINISHPAGE_NOAUTOCLOSE
  !define MUI_UNFINISHPAGE_NOAUTOCLOSE

  ; add checkbox for opening the documentation in the user's default web browser
  !define MUI_FINISHPAGE_RUN
  !define MUI_FINISHPAGE_RUN_TEXT "Open online manual in web browser"
  !define MUI_FINISHPAGE_RUN_FUNCTION "OpenDocs"
  !define MUI_FINISHPAGE_RUN_NOTCHECKED

  ; make global installation mode the default choice
  ; see MULTIUSER_PAGE_INSTALLMODE macro below
  !undef MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER

  Function OpenDocs
    ExecShell "" "https://streamlink.github.io/cli.html"
  FunctionEnd

  ; add checkbox for editing the configuration file
  !define MUI_FINISHPAGE_SHOWREADME
  !define MUI_FINISHPAGE_SHOWREADME_TEXT "Edit configuration file"
  !define MUI_FINISHPAGE_SHOWREADME_FUNCTION "EditConfig"
  !define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

  Function EditConfig
    SetShellVarContext current
    Exec '"$WINDIR\notepad.exe" "$APPDATA\streamlink\config"'
    SetShellVarContext all
  FunctionEnd

  ; constants need to be defined before importing MUI
  [[ super() ]]

  ; Add the product version information
  VIProductVersion "${VI_VERSION}"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "Streamlink"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "Streamlink"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "Streamlink Installer"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" ""
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${VERSION}"
[% endblock %]

; UI pages
[% block ui_pages %]
  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MULTIUSER_PAGE_INSTALLMODE
  !insertmacro MUI_PAGE_DIRECTORY
  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro MUI_PAGE_FINISH
[% endblock ui_pages %]

[% block sections %]
  [[ super() ]]
  SubSection /e "Bundled tools" bundled
    Section "FFMPEG" ffmpeg
      SetOutPath "$INSTDIR\ffmpeg"
      File /r "${DIR_BUILD}/ffmpeg/*.*"
      SetShellVarContext current
      ${ConfigWrite} "$APPDATA\streamlink\config" "ffmpeg-ffmpeg=" "$INSTDIR\ffmpeg\ffmpeg.exe" $R0
      SetShellVarContext all
      SetOutPath -
    SectionEnd
  SubSectionEnd
[% endblock %]

[% block install_files %]
  [[ super() ]]
  ; Install config file
  SetShellVarContext current # install the config file for the current user
  SetOverwrite off # never overwrite the config file
  SetOutPath $APPDATA\streamlink
  File /r "${DIR_BUILD}/config"
  SetOverwrite ifnewer
  SetOutPath -
  SetShellVarContext all

  ; Add metadata
  ; hijack the install_files block for this
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${PRODUCT_NAME}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${PRODUCT_NAME}" "Publisher" "Streamlink"
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${PRODUCT_NAME}" "URLInfoAbout" "https://streamlink.github.io/"
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${PRODUCT_NAME}" "HelpLink" "https://streamlink.github.io/"
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${PRODUCT_NAME}" "EstimatedSize" "$0"
[% endblock %]

[% block uninstall_files %]
  [[ super() ]]
  RMDir /r "$INSTDIR\ffmpeg"
[% endblock %]

[% block install_commands %]
  ; Remove any existing bin dir from %PATH% to avoid duplicates
  [% if has_commands %]
    nsExec::ExecToLog '[[ python ]] -Es "$INSTDIR\_system_path.py" remove "$INSTDIR\bin"'
  [% endif %]
  [[ super() ]]
[% endblock install_commands %]

[% block install_shortcuts %]
  ; Remove shortcut from previous releases
  Delete "$SMPROGRAMS\Streamlink.lnk"
[% endblock %]

[% block uninstall_shortcuts %]
  ; no shortcuts to be removed...
[% endblock %]

[% block mouseover_messages %]
  [[ super() ]]
  StrCmp $0 ${sec_app} "" +2
    SendMessage $R0 ${WM_SETTEXT} 0 "STR:${PRODUCT_NAME} with embedded Python"
  StrCmp $0 ${bundled} "" +2
    SendMessage $R0 ${WM_SETTEXT} 0 "STR:Extra tools used to play some streams"
  StrCmp $0 ${ffmpeg} "" +2
    SendMessage $R0 ${WM_SETTEXT} 0 "STR:FFMPEG is used to mux separate video and audio streams, for example DASH streams or high quality YouTube videos"
[% endblock %]
