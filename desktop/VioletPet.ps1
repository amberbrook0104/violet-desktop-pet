param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$script:mutex = New-Object System.Threading.Mutex($false, 'Local\MimoVioletEvergardenPet')
$locked = $false
try {
    try { $locked = $script:mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked -and -not $SelfTest) { return }
    $source = New-Object Windows.Media.Imaging.BitmapImage
    $source.BeginInit()
    $source.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $source.UriSource = New-Object System.Uri((Join-Path $PSScriptRoot 'spritesheet.png'))
    $source.EndInit()
    $source.Freeze()
    if ($source.PixelWidth -ne 1536 -or $source.PixelHeight -ne 1872) { throw 'Unexpected spritesheet dimensions.' }
    $script:states = [ordered]@{
        idle = @{ Row=0; Durations=@(280,110,110,140,140,320) }
        'running-right' = @{ Row=1; Durations=@(120,120,120,120,120,120,120,220) }
        'running-left' = @{ Row=2; Durations=@(120,120,120,120,120,120,120,220) }
        waving = @{ Row=3; Durations=@(140,140,140,280) }
        jumping = @{ Row=4; Durations=@(140,140,140,140,280) }
        failed = @{ Row=5; Durations=@(140,140,140,140,140,140,140,240) }
        waiting = @{ Row=6; Durations=@(150,150,150,150,150,260) }
        running = @{ Row=7; Durations=@(120,120,120,120,120,220) }
        review = @{ Row=8; Durations=@(150,150,150,150,150,280) }
    }
    $script:cache = @{}
    foreach ($key in $script:states.Keys) {
        $frames = @()
        for ($i = 0; $i -lt $script:states[$key].Durations.Count; $i++) {
            $rect = New-Object Windows.Int32Rect(($i * 192), ($script:states[$key].Row * 208),192,208)
            $frame = New-Object Windows.Media.Imaging.CroppedBitmap($source,$rect)
            $frame.Freeze()
            $frames += $frame
        }
        $script:cache[$key] = $frames
    }
    $script:window = New-Object Windows.Window
    $script:window.Title = '薇尔莉特 · 桌面陪伴'
    $script:window.Width = 192
    $script:window.Height = 208
    $script:window.WindowStyle = 'None'
    $script:window.ResizeMode = 'NoResize'
    $script:window.AllowsTransparency = $true
    $script:window.Background = [Windows.Media.Brushes]::Transparent
    $script:window.ShowInTaskbar = $false
    $script:window.Topmost = $true
    $script:window.UseLayoutRounding = $true
    $script:picture = New-Object Windows.Controls.Image
    $script:picture.Stretch = 'Uniform'
    $script:picture.Cursor = [Windows.Input.Cursors]::Hand
    $script:picture.ToolTip = '拖动搬家 · 单击挥手 · 双击跳跃 · 右键菜单'
    $script:window.Content = $script:picture
    $script:clock = [Diagnostics.Stopwatch]::StartNew()
    $script:current = 'idle'
    $script:frameIndex = 0
    $script:returnAt = 0.0
    $script:paused = $false
    $script:drag = $null
    $script:settings = Join-Path $PSScriptRoot 'settings.json'
    $area = [Windows.SystemParameters]::WorkArea
    $script:window.Left = $area.Right - 224
    $script:window.Top = $area.Bottom - 220
    if (Test-Path -LiteralPath $script:settings) {
        try {
            $saved = Get-Content -LiteralPath $script:settings -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:window.Left = [Math]::Max($area.Left,[Math]::Min([double]$saved.Left,$area.Right - 192))
            $script:window.Top = [Math]::Max($area.Top,[Math]::Min([double]$saved.Top,$area.Bottom - 208))
            if ($saved.Topmost -is [bool]) { $script:window.Topmost = $saved.Topmost }
        } catch { Write-Verbose 'Ignoring invalid saved position.' }
    }
    function Save-PetPosition {
        try {
            @{ Left=$script:window.Left; Top=$script:window.Top; Topmost=$script:window.Topmost } |
                ConvertTo-Json | Set-Content -LiteralPath $script:settings -Encoding UTF8
        } catch { Write-Verbose 'Could not save position.' }
    }
    $script:timer = New-Object Windows.Threading.DispatcherTimer
    function Show-Frame {
        $script:picture.Source = $script:cache[$script:current][$script:frameIndex]
        $script:timer.Interval = [TimeSpan]::FromMilliseconds($script:states[$script:current].Durations[$script:frameIndex])
    }
    function Set-PetState([string]$key, [double]$seconds = 0) {
        $script:current = $key
        $script:frameIndex = 0
        $script:returnAt = $(if ($seconds -gt 0) { $script:clock.Elapsed.TotalSeconds + $seconds } else { 0 })
        Show-Frame
    }
    $script:timer.Add_Tick({
        if ($script:returnAt -gt 0 -and $script:clock.Elapsed.TotalSeconds -ge $script:returnAt) { Set-PetState 'idle' }
        elseif (-not $script:paused) {
            $script:frameIndex = ($script:frameIndex + 1) % $script:cache[$script:current].Count
            Show-Frame
        }
    })
    $script:picture.Add_MouseLeftButtonDown({
        param($sender,$eventArgs)
        if ($eventArgs.ClickCount -eq 2) { Set-PetState 'jumping' 1.5; $eventArgs.Handled=$true; return }
        $point = $script:window.PointToScreen($eventArgs.GetPosition($script:window))
        $dpi = [Windows.PresentationSource]::FromVisual($script:window).CompositionTarget.TransformToDevice
        $script:drag = @{ X=$point.X; Y=$point.Y; Left=$script:window.Left; Top=$script:window.Top; DpiX=$dpi.M11; DpiY=$dpi.M22; Moved=$false; LastX=$point.X }
        [void]$script:picture.CaptureMouse()
        $eventArgs.Handled=$true
    })
    $script:picture.Add_MouseMove({
        param($sender,$eventArgs)
        if ($null -eq $script:drag -or $eventArgs.LeftButton -ne 'Pressed') { return }
        $point = $script:window.PointToScreen($eventArgs.GetPosition($script:window))
        $dx = ($point.X - $script:drag.X) / $script:drag.DpiX
        $dy = ($point.Y - $script:drag.Y) / $script:drag.DpiY
        if ([Math]::Abs($dx) + [Math]::Abs($dy) -gt 4) { $script:drag.Moved=$true }
        if ($script:drag.Moved) {
            $script:window.Left = $script:drag.Left + $dx
            $script:window.Top = $script:drag.Top + $dy
            $direction = $(if ($point.X -ge $script:drag.LastX) { 'running-right' } else { 'running-left' })
            if ($script:current -ne $direction) { Set-PetState $direction }
            $script:drag.LastX=$point.X
        }
    })
    $script:picture.Add_MouseLeftButtonUp({
        param($sender,$eventArgs)
        if ($null -eq $script:drag) { return }
        $moved=$script:drag.Moved
        $script:drag=$null
        $script:picture.ReleaseMouseCapture()
        if ($moved) { Set-PetState 'idle'; Save-PetPosition } else { Set-PetState 'waving' 1.5 }
        $eventArgs.Handled=$true
    })
    $script:picture.Add_LostMouseCapture({
        if ($null -ne $script:drag) { $script:drag=$null; Set-PetState 'idle'; Save-PetPosition }
    })
    $menu = New-Object Windows.Controls.ContextMenu
    $title = New-Object Windows.Controls.MenuItem
    $title.Header='薇尔莉特 · 桌面陪伴'
    $title.IsEnabled=$false
    [void]$menu.Items.Add($title)
    foreach ($entry in @(@('挥挥手','waving'),@('跳一下','jumping'),@('等你回应','waiting'),@('专注工作','running'),@('认真检查','review'),@('有一点失落','failed'),@('安静陪伴','idle'))) {
        $item=New-Object Windows.Controls.MenuItem
        $item.Header=$entry[0]
        $item.Tag=$entry[1]
        $item.Add_Click({ Set-PetState ([string]$this.Tag) })
        [void]$menu.Items.Add($item)
    }
    [void]$menu.Items.Add((New-Object Windows.Controls.Separator))
    $pause=New-Object Windows.Controls.MenuItem
    $pause.Header='暂停动画'
    $pause.IsCheckable=$true
    $pause.Add_Click({ $script:paused=$this.IsChecked; if ($script:paused) { Set-PetState 'idle' } })
    [void]$menu.Items.Add($pause)
    $pin=New-Object Windows.Controls.MenuItem
    $pin.Header='始终置顶'
    $pin.IsCheckable=$true
    $pin.IsChecked=$script:window.Topmost
    $pin.Add_Click({ $script:window.Topmost=$this.IsChecked; Save-PetPosition })
    [void]$menu.Items.Add($pin)
    $quit=New-Object Windows.Controls.MenuItem
    $quit.Header='退出'
    $quit.Add_Click({ $script:window.Close() })
    [void]$menu.Items.Add($quit)
    $script:picture.ContextMenu=$menu
    $script:window.Add_PreviewKeyDown({ param($sender,$eventArgs); if ($eventArgs.Key -eq 'Escape') { $script:window.Close() } })
    $script:window.Add_Closed({ $script:timer.Stop(); if (-not $SelfTest) { Save-PetPosition } })
    Set-PetState 'idle'
    if ($SelfTest) {
        $total=0
        foreach ($key in $script:states.Keys) {
            Set-PetState $key
            foreach ($frame in $script:cache[$key]) {
                if ($frame.PixelWidth -ne 192 -or $frame.PixelHeight -ne 208) { throw "Bad frame in $key" }
                $total++
            }
        }
        $script:window.Close()
        Write-Output "PASS: $total frames loaded; all 9 desktop animation states ready."
    } else {
        $script:timer.Start()
        [void]$script:window.ShowDialog()
    }
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'pet-error.log') -Encoding UTF8
    if ($SelfTest) { throw }
    [void][Windows.MessageBox]::Show("未能启动薇尔莉特。错误详情已保存到 pet-error.log。`n$($_.Exception.Message)",'薇尔莉特')
} finally {
    if ($locked) { $script:mutex.ReleaseMutex() }
    $script:mutex.Dispose()
}
