/*
 * Copyright (c) 2009, Google Inc.
 * All rights reserved.
 *
 * Copyright (c) 2009-2021, The Linux Foundation. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of The Linux Foundation nor
 *       the names of its contributors may be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "AutoGen.h"
#include "BootLinux.h"
#include "BootStats.h"
#include "KeyPad.h"
#include "LinuxLoaderLib.h"
#include <Protocol/DiskIo.h>
#include <Protocol/EFIDisplayUtils.h>
#include <FastbootLib/FastbootMain.h>
#include <Library/DeviceInfo.h>
#include <Library/DrawUI.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PartitionTableUpdate.h>
#include <Library/ShutdownServices.h>
#include <Library/StackCanary.h>
#include "Library/ThreadStack.h"
#include <Library/HypervisorMvCalls.h>
#include <Library/UpdateCmdLine.h>

#define MAX_APP_STR_LEN 64
#define MAX_NUM_FS 10
#define DEFAULT_STACK_CHK_GUARD 0xc0c0c0c0

/* R59: defined in Library/avb/VerifiedBoot.c, consumed by LoadImageFromEsp() */
extern CHAR16 gEspBootPath[64];

STATIC BOOLEAN BootReasonAlarm = FALSE;
STATIC BOOLEAN BootIntoFastboot = FALSE;
STATIC BOOLEAN BootIntoRecovery = FALSE;

// This function is used to Deactivate MDTP by entering recovery UI
STATIC EFI_STATUS MdtpDisable (VOID)
{
  BOOLEAN MdtpActive = FALSE;
  EFI_STATUS Status = EFI_SUCCESS;
  QCOM_MDTP_PROTOCOL *MdtpProtocol;

  if (FixedPcdGetBool (EnableMdtpSupport)) {
    Status = IsMdtpActive (&MdtpActive);

    if (EFI_ERROR (Status))
      return Status;

    if (MdtpActive) {
      Status = gBS->LocateProtocol (&gQcomMdtpProtocolGuid, NULL,
                                    (VOID **)&MdtpProtocol);
      if (EFI_ERROR (Status)) {
        DEBUG ((EFI_D_ERROR, "Failed to locate MDTP protocol, Status=%r\n",
                Status));
        return Status;
      }
      /* Perform Local Deactivation of MDTP */
      Status = MdtpProtocol->MdtpDeactivate (MdtpProtocol, FALSE);
    }
  }

  return Status;
}

STATIC UINT8
GetRebootReason (UINT32 *ResetReason)
{
  EFI_RESETREASON_PROTOCOL *RstReasonIf;
  EFI_STATUS Status;

  Status = gBS->LocateProtocol (&gEfiResetReasonProtocolGuid, NULL,
                                (VOID **)&RstReasonIf);
  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Error locating the reset reason protocol\n"));
    return Status;
  }

  RstReasonIf->GetResetReason (RstReasonIf, ResetReason, NULL, NULL);
  if (RstReasonIf->Revision >= EFI_RESETREASON_PROTOCOL_REVISION)
    RstReasonIf->ClearResetReason (RstReasonIf);
  return Status;
}

BOOLEAN IsABRetryCountUpdateRequired (VOID)
{
  BOOLEAN BatteryStatus;

  /* Check power off charging */
  TargetPauseForBatteryCharge (&BatteryStatus);

  /* Do not decrement bootable retry count in below states:
     * fastboot, fastbootd, charger, recovery
     */
  if ((BatteryStatus &&
       IsChargingScreenEnable ()) ||
       BootIntoFastboot ||
       BootIntoRecovery) {
    return FALSE;
  }
  return TRUE;
}

#if TARGET_BOARD_TYPE_AUTO
STATIC UINT8
WaitForDisplayCompletion (VOID)
{
  EFI_STATUS Status;
  EfiQcomDisplayUtilsProtocol *pDisplayUtilsProtocol = NULL;
  CHAR8 *sLockName = "DispInit";

  Status = gBS->LocateProtocol (&gQcomDisplayUtilsProtocolGuid,
                                NULL,
                                (VOID **)&pDisplayUtilsProtocol);
  if ((EFI_ERROR (Status)) ||
      (pDisplayUtilsProtocol == NULL)) {
    DEBUG ((EFI_D_ERROR, "Failed to locate DisplayUtils protocol, Status=%r\n",
                Status));
    return Status;
  } else {
    Status = pDisplayUtilsProtocol->DisplayUtilsSetProperty (
                                     EFI_DISPLAY_UTILS_WAIT_FOR_EVENT,
                                     sLockName, strlen (sLockName));
  }

  return Status;
}
#else
STATIC UINT8
WaitForDisplayCompletion (VOID)
{
  return EFI_SUCCESS;
}
#endif

/**
  Linux Loader Application EntryPoint

  @param[in] ImageHandle    The firmware allocated handle for the EFI image.
  @param[in] SystemTable    A pointer to the EFI System Table.

  @retval EFI_SUCCESS       The entry point is executed successfully.
  @retval other             Some error occurs when executing this entry point.

 **/


/* R58 y700-elden: stage log on the ESP (\\loader.log), opened as the very first
 * thing in the entry point. The panel channel is unreliable inside LinuxLoader
 * and a late failure powers the machine off, so the only dependable record is a
 * file on the volume we were loaded from. */
STATIC EFI_FILE_PROTOCOL  *mLLog = NULL;

STATIC VOID
LLogOpen (IN EFI_HANDLE ImageHandle)
{
  EFI_STATUS                       Status;
  EFI_LOADED_IMAGE_PROTOCOL        *LI  = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *Sfs = NULL;
  EFI_FILE_PROTOCOL                *Root = NULL;

  Status = gBS->OpenProtocol (ImageHandle, &gEfiLoadedImageProtocolGuid,
                              (VOID **)&LI, ImageHandle, NULL,
                              EFI_OPEN_PROTOCOL_GET_PROTOCOL);
  if (EFI_ERROR (Status) || (LI == NULL)) {
    return;
  }
  Status = gBS->HandleProtocol (LI->DeviceHandle,
                                &gEfiSimpleFileSystemProtocolGuid,
                                (VOID **)&Sfs);
  if (EFI_ERROR (Status) || (Sfs == NULL)) {
    return;
  }
  if (EFI_ERROR (Sfs->OpenVolume (Sfs, &Root)) || (Root == NULL)) {
    return;
  }
  /* delete a previous attempt, then create fresh.
   * 2026-11-08R61 y700-elden: **绝不能**用 `Open(Root, NULL, ...)` 表达「删除」。UEFI 规范说
   * NewHandle==NULL + 非 CREATE = 删除，但本树 EnhancedFatDxe 的 FatOpenEx() 只校验 FileName 和
   * OpenMode，**没有 NewHandle==NULL 的检查**，于是「文件存在 ⇒ 打开成功 ⇒ `*NewHandle = &NewIFile->Handle`
   * 写地址 0」→ 同步异常（data abort）落在 Fat.efi 的 `str x8,[x22]`（RVA 0x4E2C）。
   * 现场证据：屏上 `Synchronous Exception at 0xD0B99E2C`，且 `0xD0B99E2C - 0xD0B95000(Fat 装载基址)
   * = 0x4E2C` 正好是那条 store；一次成功之后每发必崩，正是「\loader.log 已存在」这条判据。
   * 正确写法：打开拿到句柄再 `->Delete()`（Delete 兼带 Close）。 */
  {
    EFI_FILE_PROTOCOL  *Old = NULL;

    if (!EFI_ERROR (Root->Open (Root, &Old, (CHAR16 *)L"\\loader.log",
                                EFI_FILE_MODE_READ | EFI_FILE_MODE_WRITE, 0)) &&
        (Old != NULL)) {
      Old->Delete (Old);
    }
  }
  if (EFI_ERROR (Root->Open (Root, &mLLog, (CHAR16 *)L"\\loader.log",
                             EFI_FILE_MODE_READ | EFI_FILE_MODE_WRITE |
                             EFI_FILE_MODE_CREATE, 0))) {
    mLLog = NULL;
  }
  Root->Close (Root);
}

STATIC VOID
LLog (IN CONST CHAR8 *Line, IN UINT64 Val)
{
  CHAR8  Buf[128];
  UINTN  N;

  if (mLLog == NULL) {
    return;
  }
  if (Val == MAX_UINT64) {
    N = AsciiStrLen (Line);
    CopyMem (Buf, Line, N);
    Buf[N++] = '\n';
  } else {
    N = AsciiSPrint (Buf, sizeof (Buf) - 1, "%a %lu\n", Line, Val);
  }
  mLLog->Write (mLLog, &N, Buf);
  mLLog->Flush (mLLog);
}

/* R59 y700-elden: does <Name> exist on the volume we were loaded from? */
STATIC BOOLEAN
LEspHasFile (IN EFI_HANDLE ImageHandle, IN CONST CHAR16 *Name)
{
  EFI_LOADED_IMAGE_PROTOCOL        *LI   = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *Sfs  = NULL;
  EFI_FILE_PROTOCOL                *Root = NULL;
  EFI_FILE_PROTOCOL                *File = NULL;
  BOOLEAN                           Found = FALSE;

  if (EFI_ERROR (gBS->OpenProtocol (ImageHandle, &gEfiLoadedImageProtocolGuid,
                                    (VOID **)&LI, ImageHandle, NULL,
                                    EFI_OPEN_PROTOCOL_GET_PROTOCOL)) ||
      (LI == NULL)) {
    return FALSE;
  }
  if (EFI_ERROR (gBS->HandleProtocol (LI->DeviceHandle,
                                      &gEfiSimpleFileSystemProtocolGuid,
                                      (VOID **)&Sfs)) || (Sfs == NULL)) {
    return FALSE;
  }
  if (EFI_ERROR (Sfs->OpenVolume (Sfs, &Root)) || (Root == NULL)) {
    return FALSE;
  }
  if (!EFI_ERROR (Root->Open (Root, &File, (CHAR16 *)Name, EFI_FILE_MODE_READ, 0)) &&
      (File != NULL)) {
    File->Close (File);
    Found = TRUE;
  }
  Root->Close (Root);
  return Found;
}

/* R59 y700-elden: log a line with a string value (menu labels/paths). */
STATIC VOID
LLogStr (IN CONST CHAR8 *Line, IN CONST CHAR8 *Val)
{
  CHAR8  Buf[160];
  UINTN  N;

  if (mLLog == NULL) {
    return;
  }
  N = AsciiSPrint (Buf, sizeof (Buf) - 1, "%a %a\n", Line, Val);
  mLLog->Write (mLLog, &N, Buf);
  mLLog->Flush (mLLog);
}

/* ==========================================================================
 * R59 y700-elden: boot menu on the ESP (route B).
 *
 * Why keys-only first: the panel (SerialPortWrite) is NOT a reliable channel on
 * this platform (PITFALLS #567) while \loader.log on the ESP is. So R59 proves
 * the *input* path (ConIn -> SCAN_UP/SCAN_DOWN/SCAN_SUSPEND) with a log-only
 * menu; the on-screen UI (BootLib/DrawUI.c) comes in R60 only after that is
 * confirmed. Menu file = \menu.cfg on the ESP:
 *
 *   #timeout=5
 *   Label one|\boot\boot.img
 *   Label two|\boot\boot2.img
 *   Mu fastboot|-fastboot
 *   Power off|-poweroff
 *
 * No \menu.cfg => single default entry (\boot\boot.img), zero key waiting.
 * ========================================================================== */
#define L_MENU_MAX        8
#define L_MENU_PATH_LEN   64
#define L_MENU_LABEL_LEN  40

STATIC UINTN   mLMenuCount;
STATIC UINTN   mLMenuTimeout;
STATIC CHAR16  mLMenuPath[L_MENU_MAX][L_MENU_PATH_LEN];
STATIC CHAR8   mLMenuPathA[L_MENU_MAX][L_MENU_PATH_LEN];
STATIC CHAR8   mLMenuLabel[L_MENU_MAX][L_MENU_LABEL_LEN];

STATIC BOOLEAN
LMenuAdd (IN CONST CHAR8 *Label, IN UINTN LabelLen,
          IN CONST CHAR8 *Path,  IN UINTN PathLen)
{
  UINTN Idx;

  if (mLMenuCount >= L_MENU_MAX) {
    return FALSE;
  }
  if ((PathLen == 0) || (PathLen >= L_MENU_PATH_LEN)) {
    return FALSE;
  }
  if ((LabelLen == 0) || (LabelLen >= L_MENU_LABEL_LEN)) {
    LabelLen = 0;   /* fall back to the path as the label */
  }

  for (Idx = 0; Idx < PathLen; Idx++) {
    mLMenuPathA[mLMenuCount][Idx] = Path[Idx];
    mLMenuPath[mLMenuCount][Idx]  = (CHAR16)(UINT8)Path[Idx];
  }
  mLMenuPathA[mLMenuCount][PathLen] = 0;
  mLMenuPath[mLMenuCount][PathLen]  = 0;

  if (LabelLen == 0) {
    for (Idx = 0; Idx < PathLen; Idx++) {
      mLMenuLabel[mLMenuCount][Idx] = Path[Idx];
    }
    mLMenuLabel[mLMenuCount][PathLen] = 0;
  } else {
    for (Idx = 0; Idx < LabelLen; Idx++) {
      mLMenuLabel[mLMenuCount][Idx] = Label[Idx];
    }
    mLMenuLabel[mLMenuCount][LabelLen] = 0;
  }

  mLMenuCount++;
  return TRUE;
}

STATIC VOID
LMenuDefaults (VOID)
{
  mLMenuCount = 0;
  mLMenuTimeout = 0;
  (VOID)LMenuAdd ("Elden Linux (ESP default)", 25, "\\boot\\boot.img", 15);
}

/* Parse \menu.cfg (already read into Buf). Tolerant: malformed lines skipped. */
STATIC VOID
LMenuParse (IN CONST CHAR8 *Buf, IN UINTN Len)
{
  UINTN Start = 0;
  UINTN Pos;

  while (Start < Len) {
    UINTN End = Start;
    UINTN Bar = (UINTN)-1;
    UINTN I;

    while ((End < Len) && (Buf[End] != '\n')) {
      End++;
    }
    I = End;
    while ((I > Start) && ((Buf[I - 1] == '\r') || (Buf[I - 1] == ' '))) {
      I--;
    }
    if (I > Start) {
      if (Buf[Start] == '#') {
        /* only #timeout=<sec> is meaningful */
        if ((I - Start > 9) && (AsciiStrnCmp (&Buf[Start], "#timeout=", 9) == 0)) {
          UINTN Val = 0, K;
          for (K = Start + 9; K < I; K++) {
            if ((Buf[K] < '0') || (Buf[K] > '9')) {
              break;
            }
            Val = Val * 10 + (UINTN)(Buf[K] - '0');
          }
          if (Val <= 60) {
            mLMenuTimeout = Val;
          }
        }
      } else {
        for (Pos = Start; Pos < I; Pos++) {
          if (Buf[Pos] == '|') {
            Bar = Pos;
            break;
          }
        }
        if (Bar == (UINTN)-1) {
          (VOID)LMenuAdd (NULL, 0, &Buf[Start], I - Start);
        } else {
          (VOID)LMenuAdd (&Buf[Start], Bar - Start, &Buf[Bar + 1], I - Bar - 1);
        }
      }
    }
    Start = End + 1;
  }
}

/* Read \menu.cfg from the volume we were loaded from (the ESP). */
STATIC VOID
LMenuLoad (IN EFI_HANDLE ImageHandle)
{
  EFI_STATUS                       Status;
  EFI_LOADED_IMAGE_PROTOCOL        *LI   = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *Sfs  = NULL;
  EFI_FILE_PROTOCOL                *Root = NULL;
  EFI_FILE_PROTOCOL                *File = NULL;
  UINT64                           Size = 0;
  CHAR8                            *Buf = NULL;

  LMenuDefaults ();

  if (EFI_ERROR (gBS->OpenProtocol (ImageHandle, &gEfiLoadedImageProtocolGuid,
                                    (VOID **)&LI, ImageHandle, NULL,
                                    EFI_OPEN_PROTOCOL_GET_PROTOCOL)) ||
      (LI == NULL)) {
    return;
  }
  if (EFI_ERROR (gBS->HandleProtocol (LI->DeviceHandle,
                                      &gEfiSimpleFileSystemProtocolGuid,
                                      (VOID **)&Sfs)) || (Sfs == NULL)) {
    return;
  }
  if (EFI_ERROR (Sfs->OpenVolume (Sfs, &Root)) || (Root == NULL)) {
    return;
  }

  Status = Root->Open (Root, &File, (CHAR16 *)L"\\menu.cfg",
                       EFI_FILE_MODE_READ, 0);
  if (EFI_ERROR (Status) || (File == NULL)) {
    LLog ("[L] menu default (no menu.cfg)", MAX_UINT64);
    Root->Close (Root);
    return;
  }

  if (!EFI_ERROR (File->SetPosition (File, 0xFFFFFFFFFFFFFFFFULL)) &&
      !EFI_ERROR (File->GetPosition (File, &Size)) &&
      (Size > 0) && (Size < 8192) &&
      !EFI_ERROR (File->SetPosition (File, 0))) {
    Buf = AllocatePool ((UINTN)Size + 1);
    if (Buf != NULL) {
      UINTN Read = (UINTN)Size;
      if (!EFI_ERROR (File->Read (File, &Read, Buf))) {
        Buf[Read] = 0;
        mLMenuCount = 0;
        LMenuParse (Buf, Read);
        if (mLMenuCount == 0) {
          LMenuDefaults ();
        }
      }
      FreePool (Buf);
    }
  }
  File->Close (File);
  Root->Close (Root);
  LLog ("[L] menu entry n", (UINT64)mLMenuCount);
  LLog ("[L] menu timeout s", (UINT64)mLMenuTimeout);
}

/* Poll ConIn for one scancode; SCAN_NULL = nothing available. */
STATIC UINT32
LMenuKey (VOID)
{
  UINT32 Key = SCAN_NULL;

  if (GetKeyPress (&Key) != EFI_SUCCESS) {
    return SCAN_NULL;
  }
  return Key;
}

/* R60 y700-elden: on-screen menu. 走 BootLib/DrawUI 的既有绘制路径（fastboot 菜单同一套：
 * DrawMenuInit 备份开屏 logo + 清屏，SetMenuMsgInfo/DrawMenu 逐行画，UpdateMsgBackground 反白选中项）。
 * × 不用 printf/SerialPortWrite 画菜单：那是帧缓冲控制台写穿的老坑（PITFALLS #514/#515/#567）。 */
STATIC MENU_MSG_INFO  mLMenuUI[L_MENU_MAX + 1];
STATIC UINT32         mLMenuUILoc[L_MENU_MAX + 1];
STATIC UINT32         mLMenuUILines;
STATIC UINT32         mLMenuUIHeight;
STATIC UINT32         mLMenuUISel = (UINT32)-1;

STATIC VOID
LMenuDrawRow (
  IN UINT32    Row,
  IN CHAR8    *Msg,
  IN UINT32    BgColor,
  IN UINT8     Attr
  )
{
  UINT32         Height = 0;
  MENU_MSG_INFO  *Item  = &mLMenuUI[Row];

  SetMenuMsgInfo (Item, Msg, COMMON_FACTOR, BGR_WHITE, BgColor, Attr,
                  mLMenuUILoc[Row], 0);
  if (DrawMenu (Item, &Height) == EFI_SUCCESS) {
    mLMenuUIHeight = Height;
    if ((Row + 1) < ARRAY_SIZE (mLMenuUI)) {
      mLMenuUILoc[Row + 1] = mLMenuUILoc[Row] + Height;
    }
  }
}

/* 画整屏：标题 + 各条目（选中项反白）+ 底部提示 */
STATIC VOID
LMenuDrawScreen (IN UINTN Sel)
{
  CHAR8   Title[80];
  CHAR8   Hint[80];
  UINTN   Idx;

  /* 只初始化一次：DrawMenuInit 会备份 logo 并清屏，重复调用会清掉已画内容 */
  if (mLMenuUILines == 0) {
    DrawMenuInit ();
    mLMenuUILoc[0] = 0;
  }

  AsciiSPrint (Title, sizeof (Title) - 1,
               "Boot menu   (Vol +/- move, Power = OK, %lu s timeout)",
               (UINT64)mLMenuTimeout);
  LMenuDrawRow (0, Title, BGR_BLACK, COMMON);

  for (Idx = 0; Idx < mLMenuCount; Idx++) {
    LMenuDrawRow ((UINT32)Idx + 1, mLMenuLabel[Idx], BGR_BLACK, COMMON);
  }

  AsciiSPrint (Hint, sizeof (Hint) - 1, " ");
  LMenuDrawRow ((UINT32)mLMenuCount + 1, Hint, BGR_BLACK, COMMON);
  mLMenuUILines = 1;

  /* 反白选中项 */
  if ((Sel < mLMenuCount) && (mLMenuUI[Sel + 1].Msg[0] != 0)) {
    (VOID)UpdateMsgBackground (&mLMenuUI[Sel + 1], BGR_BLUE);
    mLMenuUISel = (UINT32)Sel;
  }
}

/* 只移动高亮：把旧项底色还原、新项反白（避免整屏重画导致闪屏） */
STATIC VOID
LMenuDrawSelect (IN UINTN Sel)
{
  if (mLMenuUISel == (UINT32)Sel) {
    return;
  }
  if (mLMenuUISel < mLMenuCount) {
    (VOID)UpdateMsgBackground (&mLMenuUI[mLMenuUISel + 1], BGR_BLACK);
  }
  if (Sel < mLMenuCount) {
    (VOID)UpdateMsgBackground (&mLMenuUI[Sel + 1], BGR_BLUE);
  }
  mLMenuUISel = (UINT32)Sel;
}

/* Key-driven selection. Returns TRUE if the caller should boot something,
 * FALSE if the menu already handled the choice (fastboot / power off). */
STATIC BOOLEAN
LMenuSelect (IN EFI_HANDLE ImageHandle)
{
  UINTN  Sel = 0;
  UINT64 Start;
  UINT32 Last = SCAN_NULL;
  UINTN  Idx;
  CHAR8  Line[96];

  if (LEspHasFile (ImageHandle, L"\\menu.cfg")) {
    LMenuLoad (ImageHandle);
  } else {
    LMenuDefaults ();
    LLog ("[L] menu default (no menu.cfg)", MAX_UINT64);
  }
  LLog ("[L] menu in", (UINT64)mLMenuCount);

  /* R60: 有 menu.cfg 且给了 timeout 才登屏交互；timeout=0 时保持「零等待」的旧行为 */
  if (mLMenuTimeout > 0) {
    LMenuDrawScreen (Sel);
    LLog ("[L] menu ui", (UINT64)mLMenuCount);
  }

  Start = GetTimerCountms ();
  while (mLMenuTimeout > 0) {
    UINT32 Key = LMenuKey ();

    if (Key != Last) {
      if (Key != SCAN_NULL) {
        LLog ("[L] menu key", (UINT64)Key);
        if (Key == SCAN_DOWN) {
          Sel = (Sel + 1) % mLMenuCount;
          LMenuDrawSelect (Sel);
        } else if (Key == SCAN_UP) {
          Sel = (Sel + mLMenuCount - 1) % mLMenuCount;
          LMenuDrawSelect (Sel);
        } else if (Key == SCAN_SUSPEND) {
          Last = Key;
          break;
        }
        AsciiSPrint (Line, sizeof (Line) - 1, "[L] menu sel %d", (UINT32)Sel);
        LLog (Line, MAX_UINT64);
      }
      Last = Key;
    }
    if (((GetTimerCountms () - Start) / 1000) >= mLMenuTimeout) {
      LLog ("[L] menu timeout", MAX_UINT64);
      Sel = 0;
      break;
    }
    gBS->Stall (50000);   /* 50 ms per poll */
  }
  if (mLMenuTimeout == 0) {
    Sel = 0;
  }

  /* Apply the selection. */
  if (AsciiStrnCmp (mLMenuPathA[Sel], "-fastboot", 9) == 0) {
    LLog ("[L] menu pick fastboot", MAX_UINT64);
    BootIntoFastboot = TRUE;
    return FALSE;
  }
  if (AsciiStrnCmp (mLMenuPathA[Sel], "-poweroff", 9) == 0) {
    LLog ("[L] menu pick poweroff", MAX_UINT64);
    ShutdownDevice ();
    return FALSE;
  }

  for (Idx = 0; (Idx < L_MENU_PATH_LEN - 1) && (mLMenuPathA[Sel][Idx] != 0);
       Idx++) {
    gEspBootPath[Idx] = mLMenuPath[Sel][Idx];
  }
  gEspBootPath[Idx] = 0;
  LLogStr ("[L] menu boot", mLMenuPathA[Sel]);
  return TRUE;
}


/* R58b y700-elden: \\espboot.force exists on the volume we were loaded from
 * => ignore the hard-wired/BootReason fastboot decision and take the normal
 * LoadImageAndAuth -> BootLinux path. Needed because this tree sets
 * BootIntoFastboot = TRUE unconditionally, so `fastboot boot` never reaches
 * BootLinux and the ESP experiment can never run. */
STATIC BOOLEAN
LEspForceBoot (IN EFI_HANDLE ImageHandle)
{
  EFI_STATUS                       Status;
  EFI_LOADED_IMAGE_PROTOCOL        *LI  = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *Sfs = NULL;
  EFI_FILE_PROTOCOL                *Root = NULL;
  EFI_FILE_PROTOCOL                *File = NULL;

  if (EFI_ERROR (gBS->OpenProtocol (ImageHandle, &gEfiLoadedImageProtocolGuid,
                                    (VOID **)&LI, ImageHandle, NULL,
                                    EFI_OPEN_PROTOCOL_GET_PROTOCOL)) ||
      (LI == NULL)) {
    return FALSE;
  }
  if (EFI_ERROR (gBS->HandleProtocol (LI->DeviceHandle,
                                      &gEfiSimpleFileSystemProtocolGuid,
                                      (VOID **)&Sfs)) || (Sfs == NULL)) {
    return FALSE;
  }
  if (EFI_ERROR (Sfs->OpenVolume (Sfs, &Root)) || (Root == NULL)) {
    return FALSE;
  }
  Status = Root->Open (Root, &File, (CHAR16 *)L"\\espboot.force",
                       EFI_FILE_MODE_READ, 0);
  if (!EFI_ERROR (Status) && (File != NULL)) {
    File->Close (File);
    Root->Close (Root);
    return TRUE;
  }
  Root->Close (Root);
  return FALSE;
}

EFI_STATUS EFIAPI  __attribute__ ( (no_sanitize ("safe-stack")))
LinuxLoaderEntry (IN EFI_HANDLE ImageHandle, IN EFI_SYSTEM_TABLE *SystemTable)
{
  EFI_STATUS Status;

  UINT32 BootReason = NORMAL_MODE;
  UINT32 KeyPressed = SCAN_NULL;
  /* MultiSlot Boot */
  BOOLEAN MultiSlotBoot;

  DEBUG ((EFI_D_INFO, "Loader Build Info: %a %a\n", __DATE__, __TIME__));
  DEBUG ((EFI_D_VERBOSE, "LinuxLoader Load Address to debug ABL: 0x%llx\n",
         (UINTN)LinuxLoaderEntry & (~ (0xFFF))));
  DEBUG ((EFI_D_VERBOSE, "LinuxLoaderEntry Address: 0x%llx\n",
         (UINTN)LinuxLoaderEntry));

  // 2026-11-06R28 y700-elden: 本映像链接了 FrameBufferSerialPortLib 却从不初始化它（LTO 连符号
  // 都丢了）。R21 曾用惰性初始化，但那会在**异常上下文**里被触发 → 二次异常。改为入口显式初始化；
  // 失败也不要紧，之后 SerialPortWrite 会静默丢弃。
  {
    RETURN_STATUS  EFIAPI  SerialPortInitialize (VOID);
    (VOID)SerialPortInitialize ();
  }

  LLogOpen (ImageHandle);
  LLog ("[L] entry r59-menu", MAX_UINT64);

  Status = InitThreadUnsafeStack ();

  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Unable to Allocate memory for Unsafe Stack: %r\n",
            Status));
    goto stack_guard_update_default;
  }

  StackGuardChkSetup ();

  BootStatsSetTimeStamp (BS_BL_START);

  // Initialize verified boot & Read Device Info
  Status = DeviceInfoInit ();
  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Initialize the device info failed: %r\n", Status));
    goto stack_guard_update_default;
  }

  Status = EnumeratePartitions ();

  if (EFI_ERROR (Status)) {
    DEBUG ((EFI_D_ERROR, "LinuxLoader: Could not enumerate partitions: %r\n",
            Status));
    goto stack_guard_update_default;
  }

  UpdatePartitionEntries ();
  /*Check for multislot boot support*/
  MultiSlotBoot = PartitionHasMultiSlot ((CONST CHAR16 *)L"boot");
  if (MultiSlotBoot) {
    DEBUG ((EFI_D_VERBOSE, "Multi Slot boot is supported\n"));
    FindPtnActiveSlot ();
  }

  //Status = GetKeyPress (&KeyPressed);
  //if (Status == EFI_SUCCESS) {
  //  if (KeyPressed == SCAN_DOWN)
      BootIntoFastboot = TRUE;
  //  if (KeyPressed == SCAN_UP)
  //    BootIntoRecovery = TRUE;
  //  if (KeyPressed == SCAN_ESC)
  //    RebootDevice (EMERGENCY_DLOAD);
  //} else if (Status == EFI_DEVICE_ERROR) {
  //  DEBUG ((EFI_D_ERROR, "Error reading key status: %r\n", Status));
  //  goto stack_guard_update_default;
  //}

  // check for reboot mode
  Status = GetRebootReason (&BootReason);
  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Failed to get Reboot reason: %r\n", Status));
    goto stack_guard_update_default;
  }

  switch (BootReason) {
  case FASTBOOT_MODE:
    BootIntoFastboot = TRUE;
    break;
  case RECOVERY_MODE:
    BootIntoRecovery = TRUE;
    break;
  case ALARM_BOOT:
    BootReasonAlarm = TRUE;
    break;
  case DM_VERITY_ENFORCING:
    // write to device info
    Status = EnableEnforcingMode (TRUE);
    if (Status != EFI_SUCCESS)
      goto stack_guard_update_default;
    break;
  case DM_VERITY_LOGGING:
    /* Disable MDTP if it's Enabled through Local Deactivation */
    Status = MdtpDisable ();
    if (EFI_ERROR (Status) && Status != EFI_NOT_FOUND) {
      DEBUG ((EFI_D_ERROR, "MdtpDisable Returned error: %r\n", Status));
      goto stack_guard_update_default;
    }
    // write to device info
    Status = EnableEnforcingMode (FALSE);
    if (Status != EFI_SUCCESS)
      goto stack_guard_update_default;

    break;
  case DM_VERITY_KEYSCLEAR:
    Status = ResetDeviceState ();
    if (Status != EFI_SUCCESS) {
      DEBUG ((EFI_D_ERROR, "VB Reset Device State error: %r\n", Status));
      goto stack_guard_update_default;
    }
    break;
  default:
    if (BootReason != NORMAL_MODE) {
      DEBUG ((EFI_D_ERROR,
             "Boot reason: 0x%x not handled, defaulting to Normal Boot\n",
             BootReason));
    }
    break;
  }

  Status = RecoveryInit (&BootIntoRecovery);
  if (Status != EFI_SUCCESS)
    DEBUG ((EFI_D_VERBOSE, "RecoveryInit failed ignore: %r\n", Status));

  LLog ("[L] pre-boardinit", MAX_UINT64);
  /* Populate board data required for fastboot, dtb selection and cmd line */
  Status = BoardInit ();
  LLog ("[L] boardinit st", (UINT64)Status);
  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Error finding board information: %r\n", Status));
    return Status;
  }

  DEBUG ((EFI_D_INFO, "KeyPress:%u, BootReason:%u\n", KeyPressed, BootReason));
  DEBUG ((EFI_D_INFO, "Fastboot=%d, Recovery:%d\n",
                                          BootIntoFastboot, BootIntoRecovery));
  LLog ("[L] pre-vmdata", MAX_UINT64);
  if (!GetVmData ()) {
    DEBUG ((EFI_D_ERROR, "VM Hyp calls not present\n"));
  }

  if (LEspForceBoot (ImageHandle)) {
    LLog ("[L] force-boot", MAX_UINT64);
    BootIntoFastboot = FALSE;
    BootIntoRecovery = FALSE;
  }
  /* R59: boot menu (ESP \menu.cfg). Decides *which* boot.img and can also send
   * us to fastboot / power off, so it runs after the force-boot decision. */
  /* R60: 菜单默认启用（开关改为「\menu.cfg 里的 #timeout」：缺文件或 timeout=0 ⇒ 零等待、不登屏）。
   * 早期为了二分曾用 \menu.enable 文件门控 —— 那个文件不在 ESP 上，结果整段菜单从未执行
   * （2026-11-08 实测：屏上直接进 Linux，\loader.log 里连 `[L] menu in` 都没有）。 */
  if (!LMenuSelect (ImageHandle)) {
    goto fastboot;
  }
  LLog ("[L] bootfastboot", (UINT64)BootIntoFastboot);
  if (!BootIntoFastboot) {
    BootInfo Info = {0};
    Info.MultiSlotBoot = MultiSlotBoot;
    Info.BootIntoRecovery = BootIntoRecovery;
    Info.BootReasonAlarm = BootReasonAlarm;
    LLog ("[L] pre-auth", MAX_UINT64);
    Status = LoadImageAndAuth (&Info);
    LLog ("[L] post-auth st", (UINT64)Status);
    if (Status != EFI_SUCCESS) {
      DEBUG ((EFI_D_ERROR, "LoadImageAndAuth failed: %r\n", Status));
      goto fastboot;
    }

    Status = WaitForDisplayCompletion ();
    if (Status != EFI_SUCCESS) {
      DEBUG ((EFI_D_ERROR, "Failed to wait for display completion: %r\n",
                  Status));
    }
    LLog ("[L] pre-bootlinux", MAX_UINT64);
    BootLinux (&Info);
    LLog ("[L] post-bootlinux", MAX_UINT64);
  }

fastboot:
  LLog ("[L] to-fastboot", MAX_UINT64);
  Status = WaitForDisplayCompletion ();
  if (Status != EFI_SUCCESS) {
    DEBUG ((EFI_D_ERROR, "Failed to wait for display completion: %r\n",
                Status));
  }

  DEBUG ((EFI_D_INFO, "Launching fastboot\n"));
  Status = FastbootInitialize ();
  if (EFI_ERROR (Status)) {
    DEBUG ((EFI_D_ERROR, "Failed to Launch Fastboot App: %d\n", Status));
    goto stack_guard_update_default;
  }

stack_guard_update_default:
  /*Update stack check guard with defualt value then return*/
  __stack_chk_guard = DEFAULT_STACK_CHK_GUARD;

  return Status;
}
