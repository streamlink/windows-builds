!include "FileFunc.nsh"
!include "TextFunc.nsh"

!macro NSD_SetUserData hwnd data
  nsDialogs::SetUserData ${hwnd} ${data}
!macroend
!define NSD_SetUserData `!insertmacro NSD_SetUserData`

!macro NSD_GetUserData hwnd outvar
  nsDialogs::GetUserData ${hwnd}
  Pop ${outvar}
!macroend
!define NSD_GetUserData `!insertmacro NSD_GetUserData`

Var configFileRadioBtn
Var configFileOverwrite

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

  Function pageConfigFile
    !insertmacro MUI_HEADER_TEXT "Streamlink config file" "Located at: %APPDATA%\streamlink\config"

    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
      Abort
    ${EndIf}

    ${NSD_CreateRadioButton} 0 0 100% 12u "Keep existing config file, or create a new one if it doesn't exist yet"
      Pop $configFileRadioBtn
      ${NSD_AddStyle} $configFileRadioBtn ${WS_GROUP}
      ${NSD_SetUserData} $configFileRadioBtn "off"
      ${NSD_OnClick} $configFileRadioBtn configFileRadioClick
    ${NSD_Check} $configFileRadioBtn
    ${NSD_CreateRadioButton} 0 12u 100% 12u "Overwrite existing config file, or create a new one if it doesn't exist yet"
      Pop $configFileRadioBtn
      ${NSD_SetUserData} $configFileRadioBtn "on"
      ${NSD_OnClick} $configFileRadioBtn configFileRadioClick

    ${NSD_CreateHLine} 0 24u 100%
      Pop $0
    ${NSD_CreateLabel} 0 36u 100% 36u "NOTE: New major version releases of Streamlink may contain breaking changes that require modifications of old config files"
      Pop $0

    nsDialogs::Show
  FunctionEnd

  Function configFileRadioClick
    Pop $configFileRadioBtn
    ${NSD_GetUserData} $configFileRadioBtn $configFileOverwrite
  FunctionEnd

[% endblock %]

; UI pages
[% block ui_pages %]
  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MULTIUSER_PAGE_INSTALLMODE
  !insertmacro MUI_PAGE_DIRECTORY
  page custom pageConfigFile
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

      ; https://nsis.sourceforge.io/ConfigWrite
      ; update "ffmpeg-ffmpeg" config var to the path of the bundled ffmpeg executable
      ${ConfigWrite} "$APPDATA\streamlink\config" "ffmpeg-ffmpeg=" "$INSTDIR\ffmpeg\ffmpeg.exe" $R0
      ; remove "rtmp-rtmpdump" config var which was removed in Streamlink 3.0.0
      ${ConfigWrite} "$APPDATA\streamlink\config" "rtmp-rtmpdump=" "" $R0

      SetShellVarContext all
      SetOutPath -
    SectionEnd
  SubSectionEnd
[% endblock %]

[% block install_pkgs %]
  ; Try to remove the pkgs subdirectory before installing the actual pkgs content, in case it already exists from previous
  ; installs. This prevents old plugin files from being loaded by Streamlink that are incompatible with the current version.
  ; The issue that gets introduced by this is the recursive removal of this path, and if the user has selected an
  ; install path where a different pkgs subdirectory exists for other reasons, this will be removed unintentionally.
  ; Since pynist's uninstaller invokes the same command instead of deleting all installed files and directories
  ; in reverse order explicitly, we don't care too much about adding it here.
  ; https://github.com/takluyver/pynsist/issues/66
  RMDir /r "$INSTDIR\pkgs"
  [[ super() ]]
[% endblock install_pkgs %]

[% block install_files %]
  [[ super() ]]
  ; Install config file
  SetShellVarContext current # install the config file for the current user
  ${If} $configFileOverwrite == on
    SetOverwrite on
    SetOutPath $APPDATA\streamlink
    File /r "${DIR_BUILD}/config"
  ${Else}
    SetOverwrite off
    SetOutPath $APPDATA\streamlink
    File /r "${DIR_BUILD}/config"
  ${EndIf}
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
