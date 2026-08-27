# 車輛模型分析記錄 (Vehicle Model Analysis)

> 供後續 AI 參考的車輛模型結構分析文件
> 建立日期：2026-08-26
> 探索代理：explore 子代理 × 2

---

## 1. ConceptCar 050 (目前 player.tscn 使用)

### 1.1 檔案位置
- `res://Car Model/ConceptCar 050/scene.gltf`
- `res://Car Model/ConceptCar 050/scene.bin`
- 貼圖在 `textures/` 目錄

### 1.2 節點結構
```
Sketchfab_model (root)
└── dfa245e6156544f4af51ce5991af00f8.fbx (scale 0.01)
    └── RootNode (120 子節點，扁平結構)
        ├── Cube ~ Cube.008 (車身、車窗、格柵、燈具、紅飾、塑膠件)
        ├── rim_235.001 ~ 004 (4 組輪轂父節點)
        │   ├── rims (輪轂主體)
        │   └── chrome (鍍鉻飾面)
        ├── tire_001_R17.001 ~ 004 (4 組輪胎父節點)
        │   ├── rubber_tires (輪胎橡膠)
        │   └── tire_protector (護邊/字樣)
        └── shadow (地面陰影)
```

### 1.3 輪組對應表 (已區分 FL/FR/RL/RR)

> **來源**: `player.gd` line 78-83 `CONCEPT_WHEEL_MAP` (實際運行時使用的對應)
> **注意**: GLTF 節點名使用 `.001` 格式，代碼中 `_find_visual_wheels()` 同時支援 `_001` 和 `.001` 兩種命名

| 邏輯輪位 | 物理位置 (WHEEL_SETTINGS) | GLTF 轂節點 (CONCEPT_WHEEL_MAP) | GLTF 胎節點 (CONCEPT_WHEEL_MAP) | Mesh 材質 |
|---------|-------------------------|-------------------------------|-------------------------------|----------|
| **FL** | X=-1.02, Z=-1.30 (左前) | `rim_235_001` / `rim_235.001` | `tire_001_R17_001` / `tire_001_R17.001` | rims + chrome / rubber_tires + tire_protector |
| **FR** | X=+1.02, Z=-1.30 (右前) | `rim_235_003` / `rim_235.003` | `tire_001_R17_003` / `tire_001_R17.003` | 同上 |
| **RL** | X=-1.02, Z=+1.58 (左後) | `rim_235_002` / `rim_235.002` | `tire_001_R17_002` / `tire_001_R17.002` | 同上 |
| **RR** | X=+1.02, Z=+1.58 (右後) | `rim_235_004` / `rim_235.004` | `tire_001_R17_004` / `tire_001_R17.004` | 同上 |

### 1.3.1 位置驗證 (從 WHEEL_SETTINGS 反推)
- **前輪** (Z=-1.30)：FL 左(X負)、FR 右(X正)
- **後輪** (Z=+1.58)：RL 左(X負)、RR 右(X正)
- 此與 `CONCEPT_WHEEL_MAP` 索引順序一致：001→FL, 003→FR, 002→RL, 004→RR

### 1.4 縮放分析
- fbx 根節點：`0.01` (cm → m)
- Cube 節點：`100.0` (m → cm，抵消)
- **最終有效縮放：1.0 (標準米制)**

### 1.5 材質對照表 (14 種)

| 索引 | 名稱 | 用途 | 特徵 |
|------|------|------|------|
| 0 | plastic_smooth | 黑色塑膠件 | Rough 0.608 |
| 1 | glass | 車窗玻璃 | 全透明 Rough 0 |
| 2 | grill | 進氣格柵 | 貼圖 + Normal + Specular |
| 3 | body | **車身主體** | 青綠色 + Clearcoat |
| 4 | lights | 頭燈 | 發光貼圖 |
| 5 | red_deco | 紅色裝飾 | 紅色 |
| 6 | taillights | 尾燈 | 發光貼圖 |
| 7 | blocker | 遮擋/陰影 | 純黑 |
| 8 | grill.001 | 副格柵 | 純黑 |
| 9 | rims | **輪轂** | 黑色金屬 Rough 0.45 |
| 10 | chrome | **輪轂鍍鉻** | 完美鏡面 Rough 0 |
| 11 | rubber_tires | **輪胎橡膠** | 黑色 + Normal 貼圖 |
| 12 | tire_protector | 輪胎護邊/字樣 | 深灰 |
| 13 | shadow | 地面陰影 | 半透明貼圖 |

### 1.6 Godot 整合現狀 (`player.gd`)
- `CONCEPT_WHEEL_MAP` (line 78-83) 直接對應 4 組節點名稱
- `_configure_model_wheels()` (line 368-434) 自動尋找視覺輪胎並 reparent 到物理輪胎
- `_disable_fake_shadow()` 隱藏 `*shadow*` 節點
- **無獨立煞車碟/卡鉤節點**

---

## 2. Huracan Black-Panther (備選車款)

### 2.1 檔案位置
- `res://Car Model/Huracan Black-Panther/scene.gltf`
- `res://Car Model/Huracan Black-Panther/scene.bin`
- 貼圖在 `textures/` 目錄

### 2.2 節點結構
```
Sketchfab_model (root, scale 1.0)
└── 8099f72e757d4672bfc631167de7760f.fbx (scale 1.0)
    └── RootNode
        ├── Carosserie (車身主體, 26 mesh, scale 1.0)
        ├── Roues arrière (後輪組, **scale 23.106**, 7 mesh)
        ├── Capot (引擎蓋, 2 mesh, scale 1.0)
        ├── Carosserie.002 (車身副件, 2 mesh, scale 1.0)
        ├── Toit (車頂, 1 mesh, scale 1.0)
        ├── Roues avant (前輪組, **scale 23.106**, Z位移 131.181, 7 mesh)
        └── Elargissement (寬體套件, 2 mesh, scale 1.0)
```

### 2.3 輪組結構 (未分左右，需執行時分離)

#### 前輪組 (Roues avant, node 46)
| 子節點 | Mesh | 材質 | 部位 |
|--------|------|------|------|
| RIMS BLACK_0 (×2) | 38, 39 | RIMS BLACK | 左/右輪轂(黑) |
| RIMS WHITE_0 | 40 | RIMS WHITE | 左/右輪轂(白) |
| Tire_0 | 41 | Tire | **輪胎** (含胎紋貼圖) |
| plaquette de frein.001_0 | 42 | plaquette_de_frein.001 | **煞車片/卡鉤本體** |
| visse.001_0 | 43 | - | 輪轂螺絲 |
| Material.009_0 | 44 | Material.009 (綠色金屬) | **煞車碟** |

#### 後輪組 (Roues arrière, node 30) - 結構相同
| 子節點 | Mesh | 材質 | 部位 |
|--------|------|------|------|
| RIMS BLACK_0 (×2) | 26, 27 | RIMS BLACK | 左/右輪轂(黑) |
| RIMS WHITE_0 | 28 | RIMS WHITE | 左/右輪轂(白) |
| Tire_0 | 29 | Tire | **輪胎** |
| plaquette de frein.001_0 | 30 | plaquette_de_frein.001 | **煞車片/卡鉤本體** |
| visse.001_0 | 31 | - | 輪轂螺絲 |
| Material.009_0 | 32 | Material.009 | **煞車碟** |

### 2.4 縮放分析
- 車身相關節點：`scale 1.0`
- **輪組父節點：`scale 23.106`** (極關鍵！)
- 前輪組額外 Z 位移：`131.181` (單位不明，可能是 cm)

### 2.5 車身 Mesh 對照 (26+ 個)
主要材質：`Black_fond`、`Black_metal`、`Chrome`、`Carrosserie` (車身漆)、`window`/`Vitres` (玻璃)、`f_light*` (前燈)、`r_light*` (尾燈)、`Miroir` (後視鏡)、`Cabonne` (貼圖)、`Head` (大燈)

### 2.6 煞車系統
- ✅ **煞車碟**：`Material.009` (前後各 1，合併左右)
- ✅ **煞車片/卡鉤本體**：`plaquette de frein` (前後各 1)
- ❌ 無獨立 `caliper` 節點
- ❌ 無分離左右煞車系統

### 2.7 整合到 Godot 需解決的問題

| 問題 | 難度 | 建議方案 |
|------|------|----------|
| 輪組分離 (左右) | 高 | 運行時按幾何中心 X 軸正負切分 mesh，建立 4 個獨立輪組節點 |
| 23.106× 縮放補償 | 中 | 選項 A：保留父節點縮放 (易動畫) / 選項 B：bake 到頂點 (適合物理) |
| 輪距/輪徑量測 | 中 | 從 mesh bounds 計算，對應 `WHEEL_SETTINGS` position |
| 視覺輪胎綁定 | 高 | 重寫 `_configure_model_wheels()` 對應 Huracan 節點名稱 |
| 煞車動畫 | 低 | `plaquette de frein` 做卡鉤夾緊動畫，`Material.009` 做煞車碟旋轉 |

---

## 3. 兩車對比摘要

| 維度 | ConceptCar 050 | Huracan Black-Panther |
|------|---------------|----------------------|
| **整合成熟度** | ✅ 已整合可用 | ❌ 需大量工作 |
| **輪組區分** | ✅ 預先分好 FL/FR/RL/RR | ❌ 合併前後，需執行時分離 |
| **縮放處理** | ✅ 1.0 米制 | ⚠️ 輪組 23.1× 需補償 |
| **煞車系統** | ❌ 無 | ✅ 有碟+片 |
| **輪轂細節** | 2 層 (rims+chrome) | 3 層 (BLACK×2+WHITE) |
| **輪胎細節** | 2 層 (rubber+protector) | 1 層 (含貼圖胎紋) |
| **材質數量** | 14 | 20+ (含多種車身漆變體) |
| **節點數量** | ~120 (扁平) | ~56 (分組式) |

---

## 4. 後續 AI 修改切入點

### 若要切換到 Huracan：
1. **建立 `huracan.tscn`**：新場景，VehicleBody3D + 4 VehicleWheel3D
2. **撰寫輪組分離腳本**：`huracan_wheel_splitter.gd` - 從 GLTF 載入後按 X 軸切分
3. **修改 `player.gd` 或建立 `huracan_player.gd`**：
   - 更新 `WHEEL_SETTINGS` position (需實測)
   - 重寫 `_configure_model_wheels()` 對應 Huracan 節點名
   - 新增 `_setup_brake_visuals()` 綁定煞車碟/卡鉤動畫
4. **調整物理參數**：Huracan 較重/寬，需調 `engine_power`、`mass`、`downforce` 等

### 若優化 ConceptCar：
- 新增煞車碟/卡鉤視覺 (可從 Huracan 參考)
- 升級輪胎材質 (加入 Normal map 胎紋)
- 優化 `_build_road_surface_lookup()` 效能

---

## 5. 教訓編號續接

| 編號 | 教訓 | 來源 |
|------|------|------|
| V001 | GLTF 節點結構差異大：有的扁平、有的分組；整合前必須完整分析節點樹 | ConceptCar vs Huracan |
| V002 | 縮放鏈可能多層疊加 (fbx scale × node scale)；必須追蹤完整鏈路得出有效縮放 | ConceptCar: 0.01×100=1.0 |
| V003 | 輪組未分左右的模型需執行時程序化分離；不可假設模型已區分 FL/FR/RL/RR | Huracan Roues avant/arrière |
| V004 | 煞車視覺元件命名不統一：`caliper`/`plaquette de frein`/`brake_pad` 皆可能 | Huracan 使用法文命名 |

---

## 6. 相關檔案索引

| 檔案 | 用途 |
|------|------|
| `player.gd` | 車輛物理邏輯 (line 55-76 WHEEL_SETTINGS, line 78-83 CONCEPT_WHEEL_MAP) |
| `player.tscn` | 目前使用 ConceptCar 的場景 |
| `race/player_spawner.gd` | 多人生成車輛邏輯 |
| `Car Model/ConceptCar 050/scene.gltf` | 主車模型 |
| `Car Model/Huracan Black-Panther/scene.gltf` | 備選車模型 |

---

## 7. 3D 模型分析工具安裝記錄 (2026-08-26)

### 7.1 安裝環境
- **OS**: Windows 10/11 + PowerShell 5.1
- **Python**: 3.12.7 (官方安裝程式，`/quiet InstallAllUsers=1 PrependPath=1`)
- **安裝指令**:
  ```powershell
  # 下載並安裝 Python
  $url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
  $out = "$env:TEMP\python-installer.exe"
  Invoke-WebRequest -Uri $url -OutFile $out
  Start-Process -FilePath $out -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
  
  # 安裝分析套件 (使用 py launcher)
  py -m pip install --upgrade pip
  py -m pip install pygltflib trimesh scipy
  ```

### 7.2 安裝套件版本
| 套件 | 版本 | 用途 |
|------|------|------|
| `pygltflib` | 1.16.5 | GLTF 結構化解析 (節點樹、材質、transform) |
| `trimesh` | 5.0.0 | 幾何計算 (bounds、AABB/OBB、頂點/面數) |
| `numpy` | 2.5.2 | 陣列運算 (trimesh 相依) |
| `scipy` | 1.18.1 | 凸包計算 (trimesh OBB 需要) |
| `dataclasses-json` | 0.6.7 | pygltflib 相依 |
| `marshmallow` | 3.26.2 | pygltflib 相依 |

### 7.3 分析腳本
- **位置**: `D:\Github\3d-race\analyze_gltf.py`
- **功能**: 結合 pygltflib + trimesh，輸出 JSON 含場景結構、材質、mesh bounds (local/world)
- **使用方式**:
  ```powershell
  py analyze_gltf.py "path/to/model.gltf" "output.json"
  ```

### 7.4 分析結果輸出檔案
| 檔案 | 內容 |
|------|------|
| `conceptcar_analysis.json` | ConceptCar 050 完整分析 (14 材質、64 mesh、場景 AABB) |
| `huracan_analysis.json` | Huracan Black-Panther 完整分析 (32 材質、47 mesh、場景 AABB) |

### 7.5 關鍵量測數據補充

#### ConceptCar 050 實際尺寸 (World Space)
| 項目 | 數值 (公尺) |
|------|------------|
| **車身寬度** | ~2.15 m (W-extents) |
| **車身高度** | ~0.57 m (車身主體) |
| **車身長度** | ~2.2 m (主體) / 8.8 m (含陰影投射) |
| **輪胎直徑** | ~0.76 m (rubber_tires Y-extent) |
| **輪胎寬度** | ~0.28 m (X-extent) |
| **輪轂直徑** | ~0.55 m (rims Y-extent) |
| **輪轂寬度** | ~0.25 m (X-extent) |

#### Huracan Black-Panther 實際尺寸 (World Space, 含 23.1× 縮放)
| 項目 | 數值 (公尺) | 備註 |
|------|------------|------|
| **車身寬度** | ~111.7 m | 受 23.1× 縮放影響 |
| **車身高度** | ~55.4 m | |
| **車身長度** | ~223.1 m | |
| **後輪胎直徑** | ~34.9 m | Tire Y-extent |
| **後輪胎寬度** | ~100.1 m | Tire X-extent |
| **前輪胎直徑** | ~35.5 m | |
| **前輪胎寬度** | ~103.2 m | |
| **煞車碟直徑** | ~19.0 m | Material.009 Y-extent (後) / ~17.7 m (前) |
| **煞車碟厚度** | ~6.3 m | 後 / ~18.9 m (前, 可能含卡鉤) |

> **注意**: Huracan 的世界座標尺寸巨大是因為輪組父節點 `Roues avant/arrière` 有 **23.106× 縮放**。實際車輛尺寸約為上述數值 / 23.106。
> - 實際車寬: ~111.7 / 23.1 ≈ **4.8 m** (含輪胎外緣，合理)
> - 實際車長: ~223.1 / 23.1 ≈ **9.7 m** (似乎過長，需驗證)
> - 實際輪胎直徑: ~35 / 23.1 ≈ **1.5 m** (合理)
> - 實際輪胎寬度: ~100 / 23.1 ≈ **4.3 m** (似乎過寬，需驗證 mesh 本地 bounds)

### 7.6 已知問題與後續優化
1. **Huracan 縮放驗證**: 需從 mesh local bounds 反推實際尺寸，而非 world bounds
2. **OBB 計算偶爾失敗**: 已用 try-catch 處理，部分薄片幾何體無法計算有向包圍盒
3. **編碼問題**: pygltflib 載入需指定 UTF-8，PowerShell 輸出需處理 cp950
4. **scipy 相依**: trimesh OBB 需 scipy，已安裝