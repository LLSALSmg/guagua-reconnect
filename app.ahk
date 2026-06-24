#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; ============= 嵌入音频文件 =============
if A_IsCompiled
    FileInstall "1234.wav", A_Temp "\~temp_sound.wav", 1

; 获取管理员权限
if not A_IsAdmin {
    if A_IsCompiled
        Run '*RunAs "' A_ScriptFullPath '"'
    else
        Run '*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"'
    ExitApp
}

;============= 全局配置 =============
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

ConfigDir  := A_AppData "\瓜瓜重连"
ConfigPath := ConfigDir "\config.ini"
DirCreate(ConfigDir)

AppPath       := ""
MonitorActive := False
StopRequested := False
LogLines      := []
MaxLog        := 500
LastLogCount  := 0          
MainGui       := ""
StatusCtrl    := ""
BtnStart      := ""
BtnStop       := ""
BtnSetPath    := ""
BtnLog        := ""
BtnHelp       := ""
BtnVideo      := ""
BtnUpdateLog  := ""

A_IconTip      := "瓜瓜重连 - 停止"
UserAgreed     := False
MonitorIndicator := ""
KeepTimerActive := False

; 日志窗口
LogWindow      := ""
LogWindowEdit  := ""
LogTimer       := ""

; 配置开关
Use64Only    := IniRead(ConfigPath, "Settings", "Use64Only", 0)
DualAccount  := IniRead(ConfigPath, "Settings", "DualAccount", 0)
StartHotkey  := IniRead(ConfigPath, "Settings", "StartHotkey", "F8")
PlaySoundOnly := IniRead(ConfigPath, "Settings", "PlaySoundOnly", 0)

; 重连互斥
ReconnectLock := False

; 声音冷却
SoundCoolDown  := 50000   ; 50秒
LastSoundTime  := 0

; 音频文件路径
LocalSoundFile := A_ScriptDir "\1234.wav"
TempSoundFile  := A_Temp "\~temp_sound.wav"
if FileExist(LocalSoundFile)
    SoundFilePath := LocalSoundFile
else if FileExist(TempSoundFile)
    SoundFilePath := TempSoundFile
else {
    SoundFilePath := TempSoundFile
    Log("警告：音频文件未找到，将尝试使用临时文件")
}

;============= 双账号检测坐标 =============
Account1CheckX := 15
Account1CheckY := 3
Account2CheckX := 290
Account2CheckY := 3

;============= 监视小窗口颜色判断 =============
validColors := [0xFFFFFF, 0x656565, 0x999999, 0x777777]

;============= 分辨率坐标统一配置 =============
Resolutions := Map()

; ---------- 1920x1080 ----------
Resolutions["1920x1080"] := {
    wgClose:          {x:1896, y:22},   ; 关闭 WeGame 主窗口
    wgClose2:         {x:1883, y:22},   ; 关闭 WeGame 弹出的公告
    loginAccount:     {x:1619, y:985},  ; 单账号 / 双账号1：点击“启动”按钮
    loginAccount2:    {x:1869, y:979},  ; 双账号2：点击“三个点”（更多菜单）
    loginAccount2Sub: {x:1805, y:797},  ; 双账号2：点击“小号多开”
    loginAccount2Num: {x:1613, y:709},  ; 双账号2：点击“数字账号”
    loginAccount2Ok:  {x:726,  y:747},  ; 双账号2：点击“确定启动”
    loadCheck:        {x:1164, y:297},  ; 点击游戏加载处，用于触发加载检测
    loadColorArea:    {x1:650, y1:259, x2:729, y2:260, color:0xFFB9F2}, ; 游戏加载完成检测（粉色区域）
    cherryClick1:     {x:984,  y:500},  ; 激活樱桃：点击樱桃窗口中间空白区
    cherryClick2:     {x:660,  y:760},  ; 激活樱桃：打开樱桃监视窗口
    cherryClick3:     {x:1313, y:229},  ; 激活樱桃：关闭樱桃主窗口
    server:           {x:568,  y:534},  ; 选择服务器
    channel:          {x:1254, y:648},  ; 选择频道
    connect:          {x:988,  y:888},  ; 点击“连接”
    charSelect:       {x:451,  y:433},  ; 点击角色（连点两次）
    charCheckClick:   {x:1777, y:954},  ; 点击激活樱桃右下角的监视小窗
    charLoadArea:     {x1:41, y1:70, x2:208, y2:126, color:0x0000FF}, ; 检测监视窗口是否有蓝色（角色加载成功）
    cherrySetting:    {x:1816, y:900},  ; 点击樱桃设置图标
    cherryStart:      {x:1198, y:770},  ; 点击“启动挂机”按钮
    cherryClose:      {x:1312, y:232},  ; 关闭樱桃主窗口
    hideGame:         {x:1737, y:903},  ; 隐藏游戏窗口
    closeGame1:       {x:1736, y:88},   ; 关闭游戏：点击游戏窗口的X
    closeGame2:       {x:948,  y:604},  ; 关闭游戏：点击退出确认弹窗的“确定”
    monitorClick1:    {x:1786, y:959},  ; 双账号1：点击监视窗口标题栏（拖拽起点）
    monitorTarget1:   {x:145,  y:70},   ; 双账号1：监视窗口目标位置（左上角）
    monitorClick2:    {x:1786, y:959},  ; 双账号2：点击监视窗口标题栏（拖拽起点）
    monitorTarget2:   {x:429,  y:70}    ; 双账号2：监视窗口目标位置（左上角）
}

; ---------- 2560x1440 ----------
Resolutions["2560x1440"] := {
    wgClose:          {x:2538, y:17},   ; 关闭 WeGame 主窗口
    wgClose2:         {x:2519, y:17},   ; 关闭 WeGame 弹出的公告
    loginAccount:     {x:2266, y:1360}, ; 单账号 / 双账号1：点击“启动”按钮
    loginAccount2:    {x:2510, y:1347}, ; 双账号2：点击“三个点”（更多菜单）
    loginAccount2Sub: {x:2448, y:1157}, ; 双账号2：点击“小号多开”
    loginAccount2Num: {x:2256, y:1070}, ; 双账号2：点击“数字账号”
    loginAccount2Ok:  {x:1047, y:930},  ; 双账号2：点击“确定启动”
    loadCheck:        {x:1472, y:476},  ; 点击游戏加载处，用于触发加载检测
    loadColorArea:    {x1:962, y1:440, x2:972, y2:444, color:0xFFB9F2}, ; 游戏加载完成检测（粉色区域）
    cherryClick1:     {x:1313, y:749},  ; 激活樱桃：点击樱桃窗口中间空白区
    cherryClick2:     {x:986,  y:933},  ; 激活樱桃：打开樱桃监视窗口
    cherryClick3:     {x:1630, y:415},  ; 激活樱桃：关闭樱桃主窗口
    server:           {x:896,  y:711},  ; 选择服务器
    channel:          {x:1590, y:830},  ; 选择频道
    connect:          {x:1302, y:1071}, ; 点击“连接”
    charSelect:       {x:775,  y:594},  ; 点击角色（连点两次）
    charCheckClick:   {x:2427, y:1336}, ; 点击激活樱桃右下角的监视小窗
    charLoadArea:     {x1:41, y1:70, x2:208, y2:126, color:0x0000FF}, ; 检测监视窗口是否有蓝色（角色加载成功）
    cherrySetting:    {x:2462, y:1271}, ; 点击樱桃设置图标
    cherryStart:      {x:1527, y:950},  ; 点击“启动挂机”按钮
    cherryClose:      {x:1631, y:416},  ; 关闭樱桃主窗口
    hideGame:         {x:2380, y:1267}, ; 隐藏游戏窗口
    closeGame1:       {x:2056, y:267},  ; 关闭游戏：点击游戏窗口的X
    closeGame2:       {x:1266, y:784},  ; 关闭游戏：点击退出确认弹窗的“确定”
    monitorClick1:    {x:2427, y:1319}, ; 双账号1：点击监视窗口标题栏（拖拽起点）
    monitorTarget1:   {x:146,  y:70},   ; 双账号1：监视窗口目标位置（左上角）
    monitorClick2:    {x:2427, y:1319}, ; 双账号2：点击监视窗口标题栏（拖拽起点）
    monitorTarget2:   {x:423,  y:70}    ; 双账号2：监视窗口目标位置（左上角）
}

; ---------- 3440x1440 ----------
Resolutions["3440x1440"] := {
    wgClose:          {x:3421, y:22},   ; 关闭 WeGame 主窗口
    wgClose2:         {x:3403, y:21},   ; 关闭 WeGame 弹出的公告
    loginAccount:     {x:3133, y:1356}, ; 单账号 / 双账号1：点击“启动”按钮
    loginAccount2:    {x:3391, y:1347}, ; 双账号2：点击“三个点”（更多菜单）
    loginAccount2Sub: {x:3328, y:1157}, ; 双账号2：点击“小号多开”
    loginAccount2Num: {x:3155, y:1070}, ; 双账号2：点击“数字账号”
    loginAccount2Ok:  {x:1484, y:930},  ; 双账号2：点击“确定启动”
    loadCheck:        {x:1919, y:477},  ; 点击游戏加载处，用于触发加载检测
    loadColorArea:    {x1:1404, y1:434, x2:1414, y2:444, color:0xFFB9F2}, ; 游戏加载完成检测（粉色区域）
    cherryClick1:     {x:1763, y:691},  ; 激活樱桃：点击樱桃窗口中间空白区
    cherryClick2:     {x:1424, y:933},  ; 激活樱桃：打开樱桃监视窗口
    cherryClick3:     {x:2072, y:409},  ; 激活樱桃：点击特定按钮（3440独有，用于激活后续界面）
    server:           {x:1334, y:711},  ; 选择服务器
    channel:          {x:2026, y:827},  ; 选择频道
    connect:          {x:1746, y:1071}, ; 点击“连接”
    charSelect:       {x:1214, y:594},  ; 点击角色（连点两次）
    charCheckClick:   {x:3313, y:1326}, ; 点击激活樱桃右下角的监视小窗
    charLoadArea:     {x1:41, y1:70, x2:208, y2:126, color:0x0000FF}, ; 检测监视窗口是否有蓝色（角色加载成功）
    cherrySetting:    {x:3341, y:1262}, ; 点击樱桃设置图标
    cherryStart:      {x:1958, y:950},  ; 点击“启动挂机”按钮
    cherryClose:      {x:2076, y:411},  ; 关闭樱桃主窗口
    hideGame:         {x:3260, y:1259}, ; 隐藏游戏窗口
    closeGame1:       {x:2498, y:267},  ; 关闭游戏：点击游戏窗口的X
    closeGame2:       {x:1709, y:784},  ; 关闭游戏：点击退出确认弹窗的“确定”
    monitorClick1:    {x:3309, y:1322}, ; 双账号1：点击监视窗口标题栏（拖拽起点）
    monitorTarget1:   {x:148,  y:60},   ; 双账号1：监视窗口目标位置（左上角）
    monitorClick2:    {x:3309, y:1322}, ; 双账号2：点击监视窗口标题栏（拖拽起点）
    monitorTarget2:   {x:424,  y:60}    ; 双账号2：监视窗口目标位置（左上角）
}
; ---------- 2880x1800 ----------
Resolutions["2880x1800"] := {
    wgClose:          {x:2840, y:48},   ; 关闭 WeGame 主窗口
    wgClose2:         {x:2811, y:42},   ; 关闭 WeGame 弹出的公告
    loginAccount:     {x:2279, y:1612}, ; 单账号 / 双账号1：点击“启动”按钮
    loginAccount2:    {x:2787, y:1623}, ; 双账号2：点击“三个点”（更多菜单）
    loginAccount2Sub: {x:2650, y:1228}, ; 双账号2：点击“小号多开”
    loginAccount2Num: {x:2266, y:1064}, ; 双账号2：点击“数字账号”
    loginAccount2Ok:  {x:974, y:1324}, ; 双账号2：点击“确定启动”
    loadCheck:        {x:1858, y:413},  ; 点击游戏加载处，用于触发加载检测
    loadColorArea:    {x1:826, y1:339, x2:956, y2:340, color:0xFFB9F2}, ; 游戏加载完成检测（粉色区域）
    cherryClick1:     {x:1408, y:936},  ; 激活樱桃：点击樱桃窗口中间空白区
    cherryClick2:     {x:847, y:1342}, ; 激活樱桃：打开樱桃监视窗口
    cherryClick3:     {x:2149, y:289},  ; 激活樱桃：关闭樱桃主窗口
    server:           {x:664, y:794},  ; 选择服务器
    channel:          {x:2073, y:1114}, ; 选择频道
    connect:          {x:1509, y:1514}, ; 点击“连接”
    charSelect:       {x:424,  y:680},  ; 点击角色（连点两次）
    charCheckClick:   {x:2573, y:1551}, ; 点击激活樱桃右下角的监视小窗
    charLoadArea:     {x1:41, y1:70, x2:208, y2:126, color:0x0000FF}, ; 检测监视窗口是否有蓝色（角色加载成功）
    cherrySetting:    {x:2666, y:1445}, ; 点击樱桃设置图标
    cherryStart:      {x:1919, y:1366}, ; 点击“启动挂机”按钮
    cherryClose:      {x:2147, y:283},  ; 关闭樱桃主窗口
    hideGame:         {x:2520, y:1451}, ; 隐藏游戏窗口
    closeGame1:       {x:2758, y:124},  ; 关闭游戏：点击游戏窗口的X
    closeGame2:       {x:1416, y:1019},  ; 关闭游戏：点击退出确认弹窗的“确定”
    monitorClick1:    {x:2613, y:1575}, ; 双账号1：点击监视窗口标题栏（拖拽起点）
    monitorTarget1:   {x:283,  y:154},   ; 双账号1：监视窗口目标位置（左上角）
    monitorClick2:    {x:2613, y:1575}, ; 双账号2：点击监视窗口标题栏（拖拽起点）
    monitorTarget2:   {x:852,  y:159}    ; 双账号2：监视窗口目标位置（左上角）
}
; 托盘菜单
A_TrayMenu.Delete()
A_TrayMenu.Add("显示窗口", ShowMainGui)
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "显示窗口"

; ===== 停止声音播放热键 =====
F1:: {
    try {
        SoundPlay("")
    } catch {
        ; 忽略
    }

    Log("用户手动停止声音播放")
}
; ===== 停止重连热键 =====
F11:: StopMonitor()

;============= 主流程 =============
ShowLicenseAgreement()
If !UserAgreed
    ExitApp()

If !ReadOrSetAppPath()
    ExitApp()

CreateMainGui()
SetTimer(MonitorTick, 2000)
Return

;============= 使用条款 =============
ShowLicenseAgreement() {
    Global UserAgreed
    LicenseText := "
    (
                                     《工具使用许可与免责声明》

一、重要提示
您下载、运行、使用本工具即代表已完整阅读、充分理解并自愿同意本声明全部条款；若不认可，请立即删除本工具。

二、工具说明
本工具为仅用于个人学习、本地办公自动化的开源辅助脚本，作者仅提供代码技术实现演示，不鼓励、不诱导任何违反第三方平台用户协议、法律法规的使用场景。
工具仅调用 Windows 原生键鼠、图像检索，不篡改、破解、逆向任何第三方程序，不侵入第三方软件底层数据。
工具内包含 WeGame、游戏客户端、第三方插件等外部程序交互逻辑，上述第三方软件的商标、著作权、运营规则归对应厂商独立所有；本工具与所有第三方厂商无任何合作、授权、隶属关系，仅做本地窗口自动化操作。

三、使用限制与用户义务
使用本工具带来的全部风险由用户自行承担，包括但不限于：游戏账号封禁、设备风控、账号数据丢失、系统文件异常、第三方平台处罚、财产损失等。
禁止将本工具二次打包、售卖、引流盈利；仅允许个人免费学习使用，未经作者书面许可不得公开分发、修改后商用。

四、免责条款
作者不对用户产生的直接损失、间接损失、预期收益损失、账号封禁损失、设备损耗、法律处罚承担任何民事、行政、刑事责任；用户不得就上述损失向作者发起索赔、投诉、诉讼。
作者保留随时更新、修改本免责声明、停止维护工具的权利，无需单独通知用户。

如有任何疑问可联系作者QQ：873841035
    )"

    AgreeGui := Gui("+ToolWindow", "使用许可与免责声明")
    AgreeGui.SetFont("s10", "Microsoft YaHei")
    AgreeGui.Add("Edit", "w1185 r25 -VScroll ReadOnly", LicenseText)
    AgreeGui.Add("Button", "x500 y+20 w100 Default", "同意(&A)").OnEvent("Click", AgreeClicked)
    AgreeGui.Add("Button", "x+10 w100", "不同意(&D)").OnEvent("Click", (*) => ExitApp())

    AgreeGui.Show("w1200 h550")
    WinWaitClose("ahk_id " AgreeGui.Hwnd)
    If !UserAgreed
        ExitApp()

    AgreeClicked(*) {
        Global UserAgreed
        UserAgreed := True
        AgreeGui.Destroy()
    }
}

;============= 读取或设置 WeGame 路径 =============
ReadOrSetAppPath() {
    Global AppPath, ConfigPath
    AppPath := IniRead(ConfigPath, "Settings", "AppPath", "")
    Loop {
        If (AppPath = "" Or StrLen(AppPath) < 4) {
            AppPath := InputBox("请设置WEGAME地址(右键点击WeGame图标-属性-目标)复制到脚本框即可（如有“ ”请去掉）如：D:\wegame.exe：", "首次设置地址").Value
            If (AppPath = "") {
                MsgBox("未设置地址，脚本退出。", , "IconX")
                Return False
            }
            IniWrite(AppPath, ConfigPath, "Settings", "AppPath")
        }
        If FileExist(AppPath) {
            Log("WeGame 路径：" AppPath)
            Return True
        } Else {
            MsgBox("找不到 WeGame 程序：`n" AppPath "`n请重新输入正确的路径。", "路径错误", "IconX")
            AppPath := ""
            IniWrite("", ConfigPath, "Settings", "AppPath")
        }
    }
}

ShowUpdateLog(*) {
    UpdateText := "
    (
【瓜瓜重连 更新日志】
v1.6.2 - 2026-06-26
· 新增2880*1800分辨率支持
· 修复音频播放文件丢失的问题
· 修复日志显示异常的问题
· 修修修 BUG 一堆BUG
· 修了一晚上了 特么的
· 这个世界就是一场巨大的BUG
    )"
    MsgBox(UpdateText, "更新日志", "64")
}

;============= 主界面创建 =============
CreateMainGui() {
    Global MainGui, StatusCtrl, BtnStart, BtnStop, BtnSetPath, BtnLog, BtnHelp, BtnVideo, BtnUpdateLog
    Global Use64Only, DualAccount, StartHotkey, PlaySoundOnly

    MainGui := Gui("+Resize", "瓜瓜重连 v1.6.2")
    MainGui.BackColor := "E5F7F5"
    MainGui.SetFont("s12 w700", "Microsoft YaHei")

    ; 状态文字
    MainGui.SetFont("s14 w700")
    MainGui.Add("Text", "w360 Center vStatus", "状态：停止")
    StatusCtrl := MainGui["Status"]
    StatusCtrl.Opt("cRed")
    MainGui.SetFont("s12 w700")

    ; 控制组
    MainGui.Add("GroupBox", "x10 y+15 w340 h70", "控制")
    BtnStart := MainGui.Add("Button", "xp+25 yp+25 w140 h35", "运行")
    BtnStart.SetFont("s11 w700")
    BtnStop := MainGui.Add("Button", "x+20 w140 h35 Disabled", "停止 (F11)")
    BtnStop.SetFont("s11 w700")

    ; 工具组
    MainGui.Add("GroupBox", "x10 y+15 w340 h120", "工具")
    BtnSetPath := MainGui.Add("Button", "x25 yp+25 w95 h28", "修改WG路径")
    BtnSetPath.SetFont("s9")
    BtnLog     := MainGui.Add("Button", "x+10 w95 h28", "运行日志")
    BtnLog.SetFont("s9")
    BtnUpdateLog := MainGui.Add("Button", "x+10 w95 h28", "更新日志")
    BtnUpdateLog.SetFont("s9")

    BtnHelp  := MainGui.Add("Button", "x25 y+10 w95 h28", "使用说明")
    BtnHelp.SetFont("s9")
    BtnVideo := MainGui.Add("Button", "x+10 w95 h28", "视频教程")
    BtnVideo.SetFont("s9")

    ; -------- 配置组---------
    cfgGroup := MainGui.Add("GroupBox", "x10 y+15 w340 h130", "配置   (勾选后运行)")
    cfgGroup.GetPos(&gx, &gy)

    ; ===== 第一排：辅助启动键 =====
    txtLabel := MainGui.Add("Text", "x" gx+25 " y" gy+25 " w120 h40 c0x22AA22", "辅助启动热键：")
    txtLabel.SetFont("s13")
    edStart := MainGui.AddHotkey("x" gx+25+120+1 " y" gy+25 " w50 h25 vStartHotkey", StartHotkey)
    edStart.SetFont("s10")
    edStart.OnEvent("Change", SaveStartHotkey)

    ; ===== 第二排：三个复选框并排 =====
    cbY := gy+55
    ; 1. 单64位
    cb64 := MainGui.Add("CheckBox", "x" gx+5 " y" cbY " w70 h20 vUse64Only", "单64位")
    cb64.SetFont("s11")
    cb64.Value := Use64Only
    cb64.OnEvent("Click", Toggle64Only)
    q64 := MainGui.Add("Button", "x" gx+20+54 " y" cbY " w14 h18 c" 0x00FF00 " +0x5000", "?")
    q64.SetFont("s10", "Microsoft YaHei")
    q64.OnEvent("Click", (*) => ShowClickTip("开启后仅检测64位游戏进程，否则同时检测32/64位。"))

    ; 2. 双账号
    cbDual := MainGui.Add("CheckBox", "x" gx+25+70+15 " y" cbY " w70 h20 vDualAccount", "双账号")
    cbDual.SetFont("s11")
    cbDual.Value := DualAccount
    cbDual.OnEvent("Click", ToggleDualAccount)
    qDual := MainGui.Add("Button", "x" gx+25+70+10+72 " y" cbY " w14 h18 c" 0x00FF00 " +0x5000", "?")
    qDual.SetFont("s10", "Microsoft YaHei")
    qDual.OnEvent("Click", (*) => ShowClickTip("该模式以左上角樱桃监视小窗做掉线判断（不能遮挡，移动）"))

    ; 3. 掉线播放
    cbSound := MainGui.Add("CheckBox", "x" gx+25+70+10+70+35 " y" cbY " w78 h20 vPlaySoundOnly", "掉线播放")
    cbSound.SetFont("s11")
    cbSound.Value := PlaySoundOnly
    cbSound.OnEvent("Click", TogglePlaySoundOnly)
    qSound := MainGui.Add("Button", "x" gx+25+70+10+70+10+106 " y" cbY " w14 h18 c" 0x00FF00 " +0x5000", "?")
    qSound.SetFont("s10", "Microsoft YaHei")
    qSound.OnEvent("Click", (*) => ShowClickTip("掉线后仅播放声音，不执行重连操作，有人操作时提醒掉线。F1键停止声音"))

    ; 其他事件绑定
    BtnStart.OnEvent("Click", StartMonitor)
    BtnStop.OnEvent("Click", StopMonitor)
    BtnSetPath.OnEvent("Click", ChangePath)
    BtnLog.OnEvent("Click", ShowLogWindow)
    BtnHelp.OnEvent("Click", ShowHelp)
    BtnVideo.OnEvent("Click", OpenVideo)
    BtnUpdateLog.OnEvent("Click", ShowUpdateLog)

    MainGui.Show("w380 h525")
    MainGui.OnEvent("Close", GuiClose)
    UpdateStatus()
}

; 点击问号显示提示
ShowClickTip(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -3000)
}

;============= 事件开关 =============
Toggle64Only(Ctrl, Info) {
    Global Use64Only
    Use64Only := Ctrl.Value
    IniWrite(Use64Only, ConfigPath, "Settings", "Use64Only")
    Log("单64位：" (Use64Only ? "开启" : "关闭"))
}

ToggleDualAccount(Ctrl, Info) {
    Global DualAccount
    DualAccount := Ctrl.Value
    IniWrite(DualAccount, ConfigPath, "Settings", "DualAccount")
    Log("双账号：" (DualAccount ? "开启" : "关闭"))
}

TogglePlaySoundOnly(Ctrl, Info) {
    Global PlaySoundOnly
    PlaySoundOnly := Ctrl.Value
    IniWrite(PlaySoundOnly, ConfigPath, "Settings", "PlaySoundOnly")
    Log("掉线播放：" (PlaySoundOnly ? "开启" : "关闭"))
}

SaveStartHotkey(Ctrl, Info) {
    Global StartHotkey, ConfigPath
    if Ctrl.Value = "" {
        Log("警告：热键值为空，未保存")
        return
    }
    StartHotkey := Ctrl.Value
    IniWrite(StartHotkey, ConfigPath, "Settings", "StartHotkey")
    Log("启动热键已更新：" StartHotkey)
}

ShowHelp(*) {
    HelpText := "
    (
如果遇见鼠标移动但不点击，请给予工具管理员权限：
    重连工具-右键-属性-以管理员身份运行此程序

Wegame客户端设置：
Wegame客户端右键置顶彩虹岛，点击任意公告，把公告页面最大化然后关闭。
Wegame窗口最大化，再关闭Wegame客户端。

樱桃设置：
樱桃辅助增加设置：触发-被动指令-添加 条件：游戏掉线  添加被动触发 [改] 关闭游戏 
设置完记得保存，如有连体角色切换需每个角色都设置。

重连使用说明：
1. 首次运行请先设置 WeGame 路径。（如有“ ”请去掉）
2. 点击“运行”，脚本会自动检测游戏进程。同时显示右下角绿点。
    游戏掉线或未运行时，脚本会自动重新登录并开始挂机。
3. 点击“停止”可立即停止当前重连流程，同时右下角绿点消失。
4. “运行日志”按钮可以看详细运行记录（滚动条由您控制，不会自动跳转）。
5. 关闭主窗口会最小化到系统托盘，双击托盘图标即可恢复，右键托盘可退出脚本。

配置说明：
· 单64位：开启后只检测64位游戏进程，否则同时检测32/64位。
· 双账号：开启后通过左上角辅助监视窗口检测两个账号是否在线（不能遮挡，移动）。
· 掉线播放：勾选后，掉线时仅播放提示音，不执行重连，停止播放热键：F1
· 单/双账号均支持：1920*1080  2560*1440  3440*1440  2880*1800
  其他分辨率如需使用可联系作者添加
· 启动热键：对应樱桃辅助的“启动挂机”快捷键，请在此直接按下您想要的功能键（例如 F8）。

如有问题请联系作者QQ：873841035
    )"
    MsgBox(HelpText, "使用说明", "64")
}

OpenVideo(*) {
    Run("https://www.bilibili.com/video/BV1foPKzGES3/")
}

;============= 日志窗口 =============
ShowLogWindow(*) {
    Global LogWindow, LogTimer, LogLines, LogWindowEdit, LastLogCount
    If (IsSet(LogTimer) && LogTimer) {
        SetTimer(LogTimer, 0)
        LogTimer := ""
    }
    If (IsSet(LogWindow) && LogWindow) {
        LogWindow.Destroy()
        LogWindow := ""
    }
    ; 创建窗口
    LogWindow := Gui("+Resize", "运行日志")
    LogWindow.BackColor := "FFFFFF"
    LogWindow.SetFont("s10 cBlack", "Consolas")
    LogWindowEdit := LogWindow.Add("Edit", "w700 r25 ReadOnly -Wrap", "")
    LogWindowEdit.SetFont("s10 cBlack", "Consolas")
    LastLogCount := 0
    RefreshLogContent()
    LogWindow.Show()
    LogWindow.OnEvent("Close", LogWindowClose)
    LogTimer := SetTimer(RefreshLogContent, 1000)
}

LogWindowClose(*) {
    Global LogWindow, LogTimer
    If (IsSet(LogTimer) && LogTimer) {
        SetTimer(LogTimer, 0)
        LogTimer := ""
    }
    If (IsSet(LogWindow) && LogWindow) {
        LogWindow.Destroy()
        LogWindow := ""
    }
    Global LogWindowEdit := ""
    Global LastLogCount := 0
}

RefreshLogContent() {
    Global LogWindowEdit, LogLines, LastLogCount
    If !(IsSet(LogWindowEdit) && LogWindowEdit && LogWindowEdit.Hwnd)
        Return

    total := LogLines.Length
    ; 如果有新行，则追加
    if (total > LastLogCount) {
        ; 准备要追加的文本（从 LastLogCount+1 到 total）
        newText := ""
        Loop total - LastLogCount {
            newText .= LogLines[LastLogCount + A_Index] . "`r`n"
        }
        ; 在 Edit 控件末尾插入文本
        hEdit := LogWindowEdit.Hwnd
        ; 将光标移到末尾
        SendMessage(0x00B1, -1, -1, hEdit) ; EM_SETSEL 设置到末尾
        ; 插入文本（EM_REPLACESEL = 0x00C2）
        SendMessage(0x00C2, 0, StrPtr(newText), hEdit)
        ; 更新计数
        LastLogCount := total
    }
}

;============= 其他功能函数 =============
GuiClose(*) {
    MainGui.Hide()
}

ShowMainGui(*) {
    Global MainGui
    MainGui.Show()
}

UpdateStatus(state := "") {
    Global MonitorActive, StatusCtrl, BtnStart, BtnStop
    If (state = "reconnecting") {
        StatusCtrl.Opt("cBlue")
        StatusCtrl.Value := "状态：重连中..."
        BtnStart.Enabled := False
        BtnStop.Enabled := True
        A_IconTip := "瓜瓜重连 - 重连中"
    } Else If MonitorActive {
        StatusCtrl.Opt("cGreen")
        StatusCtrl.Value := "状态：运行中"
        BtnStart.Enabled := False
        BtnStop.Enabled := True
        A_IconTip := "瓜瓜重连 - 运行中"
    } Else {
        StatusCtrl.Opt("cRed")
        StatusCtrl.Value := "状态：停止"
        BtnStart.Enabled := True
        BtnStop.Enabled := False
        A_IconTip := "瓜瓜重连 - 停止"
    }
}

StartMonitor(*) {
    Global MonitorActive, KeepTimerActive, StopRequested
    Global Use64Only, DualAccount, StartHotkey, PlaySoundOnly
    Use64Only := IniRead(ConfigPath, "Settings", "Use64Only", 0)
    DualAccount := IniRead(ConfigPath, "Settings", "DualAccount", 0)
    StartHotkey := IniRead(ConfigPath, "Settings", "StartHotkey", "F8")
    PlaySoundOnly := IniRead(ConfigPath, "Settings", "PlaySoundOnly", 0)
    Try MainGui["Use64Only"].Value := Use64Only
    Try MainGui["DualAccount"].Value := DualAccount
    Try MainGui["StartHotkey"].Value := StartHotkey
    Try MainGui["PlaySoundOnly"].Value := PlaySoundOnly

    MonitorActive := True
    StopRequested := False
    Log("重连已启动")
    ScreenW := A_ScreenWidth
    ScreenH := A_ScreenHeight
    If Resolutions.Has(ScreenW "x" ScreenH)
        Log("当前分辨率：" ScreenW "x" ScreenH "，已匹配分辨率，自动重连就绪")
    Else
        Log("当前分辨率：" ScreenW "x" ScreenH "，不支持的分辨率，请联系作者")
    UpdateStatus()
    If (!MonitorIndicator) {
        CreateMonitorIndicator()
        SetTimer(KeepIndicatorVisible, 1000)
        KeepTimerActive := True
    }
}

StopMonitor(*) {
    Global MonitorActive, KeepTimerActive, StopRequested
    MonitorActive := False
    StopRequested := True
    Log("重连已停止")
    UpdateStatus()
    DestroyMonitorIndicator()
}

ChangePath(*) {
    Global AppPath, ConfigPath
    newPath := InputBox("输入新的 WeGame 路径：", "修改路径", , AppPath).Value
    If (newPath != "") {
        AppPath := newPath
        IniWrite(AppPath, ConfigPath, "Settings", "AppPath")
        Log("路径已更新：" AppPath)
    }
}

Delay(ms, step := 200) {
    Global StopRequested
    Loop (ms // step) {
        If StopRequested
            Return False
        Sleep(step)
    }
    If StopRequested
        Return False
    Return True
}

ClickSleep(x, y, sleepMs := 500, button := "Left") {
    if (x < 0 or y < 0)
        return true
    CoordMode "Mouse", "Screen"
    MouseMove(x, y)
    Sleep(100)
    Click(button)
    if !Delay(sleepMs)
        return false
    return true
}

Log(msg) {
    Global LogLines, MaxLog
    time := FormatTime(A_Now, "HH:mm:ss")
    LogLines.Push("[" time "] " msg)
    If (LogLines.Length > MaxLog)
        LogLines.RemoveAt(1)
}

Join(sep, arr*) {
    str := ""
    For i, v in arr
        str .= (i=1 ? "" : sep) . v
    Return str
}

;============= 移动单个监视窗口（双账号） =============
MoveMonitor(account) {
    Global Resolutions, StopRequested
    resKey := A_ScreenWidth "x" A_ScreenHeight
    if !Resolutions.Has(resKey) {
        Log("未知分辨率，使用默认1920x1080")
        resKey := "1920x1080"
    }
    res := Resolutions[resKey]
    if (account = 1) {
        clickX := res.monitorClick1.x
        clickY := res.monitorClick1.y
        targetX := res.monitorTarget1.x
        targetY := res.monitorTarget1.y
    } else {
        clickX := res.monitorClick2.x
        clickY := res.monitorClick2.y
        targetX := res.monitorTarget2.x
        targetY := res.monitorTarget2.y
    }
    Log("移动账号" account " 监视窗口：点击 (" clickX "," clickY ") → 目标 (" targetX "," targetY ")")
    ; ---- 拖拽操作 ----
    if !ClickSleep(clickX, clickY, 300)
        return
    if StopRequested 
        return
    if !Delay(200) 
        return
    if !ClickSleep(clickX, clickY, 300) 
        return
    if StopRequested 
        return
    if !Delay(200) 
        return

    CoordMode "Mouse", "Screen"
    MouseMove(clickX, clickY)
    if !Delay(100) 
        return
    Click("Left", "Down")
    if !Delay(300) 
        return
    MouseMove(targetX, targetY, 2)
    if !Delay(300) 
        return
    Click("Left", "Up")
    if !Delay(300) 
        return
}

;============= 通用登录流程=============
Login(account := 1) {
    Global AppPath, StopRequested, StartHotkey, Resolutions
    resKey := A_ScreenWidth "x" A_ScreenHeight
    if !Resolutions.Has(resKey) {
        Log("不支持的分辨率：" resKey)
        Return
    }
    res := Resolutions[resKey]

    Log("启动 " resKey " 重连 (账号" account ")")
    Countdown("重连已启动，瓜！", 3)
    if StopRequested {
        Log("重连被用户终止")
        Return
    }

    Log("启动 WeGame...")
    Run(AppPath)
    if !Delay(5000) {
        Log("重连被用户终止")
        Return
    }

    ; ---------- 双账号登录分支 ----------
    if (account == 1) {
        if !ClickSleep(res.loginAccount.x, res.loginAccount.y, 200)
            return
        if !Delay(1000)
            return
    } else {
        if !ClickSleep(res.loginAccount2.x, res.loginAccount2.y, 200)
            return
        if !Delay(1000)
            return
        if !ClickSleep(res.loginAccount2Sub.x, res.loginAccount2Sub.y, 50)
            return
        if !Delay(1000)
            return
        if !ClickSleep(res.loginAccount2Num.x, res.loginAccount2Num.y, 200)
            return
        if !Delay(3000)
            return
        if !ClickSleep(res.loginAccount2Ok.x, res.loginAccount2Ok.y, 200)
            return
        if !Delay(1000)
            return
    }

    ; ---------- 通用登录流程 ----------
    if !Delay(10000) {
        Log("重连被用户终止")
        Return
    }
    if !Delay(10000) {
        Log("重连被用户终止")
        Return
    }
    if !ClickSleep(res.wgClose.x, res.wgClose.y, 500)
        return
    if !ClickSleep(res.wgClose2.x, res.wgClose2.y, 500)
        return

    ; 等待游戏加载
    Log("等待游戏加载完成...")
    startTime := A_TickCount
    timeout := 350000
    Loop {
        if StopRequested {
            Log("重连被用户终止")
            Return
        }
        if !ClickSleep(res.loadCheck.x, res.loadCheck.y, 500)
            return
        if PixelSearch(&FoundX, &FoundY, res.loadColorArea.x1, res.loadColorArea.y1,
                       res.loadColorArea.x2, res.loadColorArea.y2,
                       res.loadColorArea.color, 15) {
            Log("游戏加载完成")
            break
        }
        if (A_TickCount - startTime > timeout) {
            Log("等待超时，游戏加载失败")
            CloseGame(res)
            Return
        }
        if !Delay(1000)
            return
    }
    ; 关闭WG和公告
    if !ClickSleep(res.wgClose.x, res.wgClose.y, 500)
        return
    if !ClickSleep(res.wgClose2.x, res.wgClose2.y, 500)
        return
    if !Delay(1000) {
        Log("重连被用户终止")
        Return
    }
    Log("开始登录...")

    ; 激活樱桃并打开监视窗口
    if !ClickSleep(res.cherryClick1.x, res.cherryClick1.y, 100)
        return
    if !ClickSleep(res.cherryClick2.x, res.cherryClick2.y, 100)
        return
    if !ClickSleep(res.cherryClick3.x, res.cherryClick3.y, 100)
        return
    if !Delay(1000)
        return

    ; 选择服务器
    if !ClickSleep(res.server.x, res.server.y, 100)
        return
    if !Delay(2000)
        return
    ; 选择频道
    if !ClickSleep(res.channel.x, res.channel.y, 100)
        return
    if !Delay(1000)
        return
    ; 点击连接
    if !ClickSleep(res.connect.x, res.connect.y, 100)
        return
    if !Delay(7000)
        return

    ; 选择角色
    if !ClickSleep(res.charSelect.x, res.charSelect.y, 50)
        return
    if !ClickSleep(res.charSelect.x, res.charSelect.y, 500)
        return
    if !Delay(10000)
        return

    ; 角色加载前点击
    if !ClickSleep(res.charCheckClick.x, res.charCheckClick.y, 100)
        return
    CoordMode "Mouse", "Client"
    CoordMode "Pixel", "Client"
    found := false
    timeOut := 15000
    startTime2 := A_TickCount
    Loop {
        if StopRequested {
            Log("重连被用户终止")
            CoordMode "Pixel", "Screen"
            CoordMode "Mouse", "Screen"
            Return
        }
        if PixelSearch(&px, &py, res.charLoadArea.x1, res.charLoadArea.y1,
                       res.charLoadArea.x2, res.charLoadArea.y2,
                       res.charLoadArea.color, 0) {
            found := true
            break
        }
        if (A_TickCount - startTime2 > timeOut)
            break
        Sleep 50
    }
    CoordMode "Pixel", "Screen"
    CoordMode "Mouse", "Screen"
    if !found {
        CloseGame(res)
        return
    }

    ; 打开樱桃设置
    if !ClickSleep(res.cherrySetting.x, res.cherrySetting.y, 500)
        return
    if !Delay(1000)
        return
    ; 启动挂机
    if !ClickSleep(res.cherryStart.x, res.cherryStart.y, 1000)
        return
    Send("{" . StartHotkey . "}")
    if !Delay(500)
        return
    ; 关闭樱桃主窗口
    if !ClickSleep(res.cherryClose.x, res.cherryClose.y, 200)
        return
    ; 隐藏游戏
    if !ClickSleep(res.hideGame.x, res.hideGame.y, 200)
        return
    if !Delay(2000)
        return

    ; 最后关闭WG和公告
    if !ClickSleep(res.wgClose.x, res.wgClose.y, 500)
        return
    if !ClickSleep(res.wgClose2.x, res.wgClose2.y, 500)
        return

    Log("账号" account " 挂机已启动")
    Log("瓜帮你避免了一次掉线，快说谢谢瓜")
}

;============= 通用关闭游戏 =============
CloseGame(res) {
    Log("关闭游戏")
    if !ClickSleep(res.closeGame1.x, res.closeGame1.y, 100)
        return
    if !ClickSleep(res.closeGame2.x, res.closeGame2.y, 100)
        return
    if !Delay(1000)
        return
}

;============= 重连主函数 =============
RunReconnect(account := 1) {
    Global AppPath, StopRequested, ReconnectLock, DualAccount, Resolutions
    if ReconnectLock {
        Log("重连正在执行中，跳过本次请求")
        Return
    }
    ReconnectLock := True
    Try {
        StopRequested := False
        ScreenW := A_ScreenWidth
        ScreenH := A_ScreenHeight
        Log("当前分辨率：" ScreenW "x" ScreenH)
        RunWait("taskkill /f /im mshta.exe", , "Hide")

        resKey := ScreenW "x" ScreenH
        if !Resolutions.Has(resKey) {
            Log("不支持的分辨率，重连停止")
            Return
        }
        res := Resolutions[resKey]

        Login(account)
        If DualAccount {
            Log("双账号模式：移动账号" account " 监视窗口到预设位置")
            MoveMonitor(account)
        }
    } Finally {
        ReconnectLock := False
    }
}

Notify(msg, seconds := 3) {
}

Countdown(msg, seconds) {
    Global StopRequested
    C := Gui("+ToolWindow -Caption", "倒计时")
    C.BackColor := "222222"
    C.SetFont("s12 cAAAAAA", "Microsoft YaHei")
    C.Add("Text", "w150 Center", msg)
    C.Add("Text", "w150 Center c4CAF50 vCount", seconds)
    C.Show("w180 h100 x" A_ScreenWidth-200 " y50")
    Loop seconds {
        Loop 10 {
            Sleep(100)
            if StopRequested {
                C.Destroy()
                Return
            }
        }
        C["Count"].Value := seconds - A_Index
    }
    C.Destroy()
}

;============= 主监控定时器 =============
MonitorTick() {
    Global MonitorActive, Use64Only, DualAccount, ReconnectLock, StopRequested
    Global Account1CheckX, Account1CheckY, Account2CheckX, Account2CheckY
    Global validColors, PlaySoundOnly, LastSoundTime, SoundCoolDown, SoundFilePath, TempSoundFile
    If !MonitorActive
        Return
    If ReconnectLock {
        Return
    }

    if !FileExist(SoundFilePath) {
        Log("音频文件丢失，将使用蜂鸣提示")
    }

    if !DualAccount {
        found := False
        if Use64Only {
            if ProcessExist("LaTaleClient_x64.exe")
                found := True
        } else {
            if ProcessExist("LaTaleClient.exe") or ProcessExist("LaTaleClient_x64.exe")
                found := True
        }
        if !found {
            Log("检测到游戏未运行，开始重连...")
            if PlaySoundOnly {
                now := A_TickCount
                if (now - LastSoundTime >= SoundCoolDown) {
                    if FileExist(SoundFilePath) {
                        SoundPlay(SoundFilePath)
                        LastSoundTime := now
                        Log("播放掉线提示音")
                    } else {
                        SoundBeep(1000, 500)
                        Log("音频文件不存在，使用蜂鸣提示")
                    }
                } else {
                    Log("掉线提示音播放中...")
                }
            } else {
                UpdateStatus("reconnecting")
                RunReconnect(1)
                UpdateStatus()
            }
        }
    } else {
        color1 := PixelGetColor(Account1CheckX, Account1CheckY, "RGB")
        online1 := false
        for c in validColors
            if (color1 = c) {
                online1 := true
                break
            }

        color2 := PixelGetColor(Account2CheckX, Account2CheckY, "RGB")
        online2 := false
        for c in validColors
            if (color2 = c) {
                online2 := true
                break
            }

        needReconnect := []
        if !online1
            needReconnect.Push(1)
        if !online2
            needReconnect.Push(2)

        if needReconnect.Length > 0 {
            Log("检测到账号 " Join(",", needReconnect*) " 掉线，开始重连...")
            if PlaySoundOnly {
                now := A_TickCount
                if (now - LastSoundTime >= SoundCoolDown) {
                    if FileExist(SoundFilePath) {
                        SoundPlay(SoundFilePath)
                        LastSoundTime := now
                        Log("播放掉线提示音")
                    } else {
                        SoundBeep(1000, 500)
                        Log("音频文件不存在，使用蜂鸣提示")
                    }
                } else {
                    Log("掉线提示音播放中...")
                }
            } else {
                UpdateStatus("reconnecting")
                For _, acc in needReconnect {
                    if StopRequested
                        break
                    RunReconnect(acc)
                }
                UpdateStatus()
            }
        }
    }
}

;============= 指示器 =============
CreateMonitorIndicator() {
    Global MonitorIndicator
    If (IsSet(MonitorIndicator) && MonitorIndicator)
        Return
    MonitorIndicator := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20")
    MonitorIndicator.BackColor := "00FF00"
    MonitorIndicator.Show("w10 h10 x" (A_ScreenWidth-20) " y" (A_ScreenHeight-20) " NoActivate")
}

DestroyMonitorIndicator() {
    Global MonitorIndicator, KeepTimerActive
    If (IsSet(MonitorIndicator) && MonitorIndicator) {
        MonitorIndicator.Destroy()
        MonitorIndicator := ""
    }
    If (KeepTimerActive) {
        SetTimer(KeepIndicatorVisible, 0)
        KeepTimerActive := False
    }
}

KeepIndicatorVisible() {
    Global MonitorIndicator
    If (!IsSet(MonitorIndicator) || !MonitorIndicator)
        Return
    Try {
        If !WinExist("ahk_id " MonitorIndicator.Hwnd) {
            MonitorIndicator := CreateMonitorIndicator()
            Return
        }
        WinSetAlwaysOnTop(True, "ahk_id " MonitorIndicator.Hwnd)
        WinShow("ahk_id " MonitorIndicator.Hwnd)
    }
    Return
}
