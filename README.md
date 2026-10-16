# 薇尔莉特 · 桌面陪伴

简体中文 | [English](README.en.md)

《紫罗兰永恒花园》薇尔莉特·伊芙加登的 Q 版动画小宠物，提供 Windows 桌面版和 Codex 自定义宠物包。

![薇尔莉特挥手](qa/previews/waving.gif)

## 下载和启动

下载 [Violet-Desktop-Pet.zip](downloads/Violet-Desktop-Pet.zip)，解压后打开 `desktop` 文件夹，双击 `Start-Violet.vbs`。如果电脑未启用 VBScript，双击 `Start-Violet.cmd`。

桌面版使用 Windows 自带的 Windows PowerShell 5.1 和 WPF，无需额外安装运行环境。运行时不联网，不添加开机启动。

| 操作 | 效果 |
| --- | --- |
| 按住拖动 | 移动位置，并播放左右移动动画 |
| 单击 | 挥手 |
| 双击 | 跳跃 |
| 右键 | 切换动作、暂停动画、切换置顶或退出 |
| 获得焦点时按 Esc | 退出 |

位置和置顶设置保存在 `desktop/settings.json`。可以移动整个 `desktop` 文件夹，或为启动文件创建桌面快捷方式。

## 在 Codex 中使用

将 `package` 文件夹中的 `pet.json` 和 `spritesheet.webp` 一起复制到 Codex 的宠物目录：

```text
%USERPROFILE%\.codex\pets\violet-evergarden\
  pet.json
  spritesheet.webp
```

如果设置了 `CODEX_HOME`，则使用该目录下的 `pets/violet-evergarden`。已有同名宠物时，请先备份原文件。

在支持本地自定义宠物的桌面应用中，打开 **设置 → 宠物（Pets）→ 刷新（Refresh）**，选择 **薇尔莉特**。输入 `/pet` 可以显示或隐藏宠物浮窗。参见 [官方宠物说明](https://learn.chatgpt.com/docs/pets)。

## 动画与文件

图集尺寸为 1536 × 1872，共 8 列、9 行，每帧 192 × 208；包含 57 个有效帧，其余单元透明。

| 状态 | 帧数 | 动作 |
| --- | ---: | --- |
| idle | 6 | 安静陪伴、眨眼 |
| running-right | 8 | 向右移动 |
| running-left | 8 | 向左移动 |
| waving | 4 | 挥手 |
| jumping | 5 | 蓄力、跃起、落地 |
| failed | 8 | 失落、低头 |
| waiting | 6 | 等待回应 |
| running | 6 | 专注工作、手部动作 |
| review | 6 | 认真检查、思考 |

`running` 表示执行任务时的工作动作；左右移动使用独立的 `running-right` 和 `running-left`。

```text
desktop/             Windows 桌面程序与 PNG 图集
package/             Codex 宠物清单与 WebP 图集
qa/previews/         九组 GIF 动画预览
qa/contact-sheet.png 全部动作接触表
qa/                  图集验证与视觉检查结果
character-spec.json  角色和动作规格
downloads/           可直接下载的 ZIP 包
```

## 验证与修改

已检查全部 57 帧的角色一致性、步态方向、跳跃起落、裁切和透明背景。完整结果保存在 `qa/validation.json` 和 `qa/visual-qa.json`。

验证桌面版是否能加载全部帧：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\desktop\VioletPet.ps1 -SelfTest
```

`desktop/VioletPet.ps1` 保存窗口、交互和动画播放逻辑。角色与动作画面通过 hatch-pet 和内置 imagegen 制作；向左移动逐帧镜像自已检查的向右步态。调整造型时，需要同步更新桌面版 PNG 图集和 Codex 版 WebP 图集。
