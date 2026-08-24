# [Z 3D Race] Project Context File: .tscn

## res://

**car_inspect.tscn**
```ini
[gd_scene format=3 uid="uid://cdq7ikv12ys07"]

[ext_resource type="PackedScene" uid="uid://vw54wjuncdts" path="res://Car Model/ConceptCar 050/scene.gltf" id="1_f7drf"]
[ext_resource type="PackedScene" uid="uid://csrk1f6fryg68" path="res://AE86/AE86_2.glb" id="2_vf4gi"]

[node name="InspectRoot" type="Node3D" unique_id=1984107739]

[node name="ConceptCar" parent="." unique_id=461565383 instance=ExtResource("1_f7drf")]

[node name="AE86Ref" parent="." unique_id=1531117584 instance=ExtResource("2_vf4gi")]

```

**main.tscn**
```ini
[gd_scene format=3 uid="uid://b1v0aobmc6e2a"]

[ext_resource type="Script" uid="uid://dtkc4s0hbw2f2" path="res://finish.gd" id="2_0xm2m"]
[ext_resource type="Script" uid="uid://dxo6jim53dnvd" path="res://race_manager.gd" id="3_h2yge"]
[ext_resource type="Script" uid="uid://cm70cfbsaam80" path="res://check_point_1.gd" id="4_1bvp3"]
[ext_resource type="PackedScene" uid="uid://bq4bfthd7tmdf" path="res://ui/dashboard.tscn" id="5_getpj"]
[ext_resource type="PackedScene" uid="uid://b1piyf2oecvnn" path="res://ui/time_trial_start_screen.tscn" id="6_ryguw"]
[ext_resource type="PackedScene" uid="uid://cvei4o6n8fc4a" path="res://ui/time_trial_countdown.tscn" id="7_d13ii"]
[ext_resource type="PackedScene" uid="uid://gloiakrmjtp4" path="res://ui/time_trial_finish_screen.tscn" id="8_1u8w0"]
[ext_resource type="PackedScene" uid="uid://bxnmkg3045ww3" path="res://race_map.glb" id="8_map"]
[ext_resource type="PackedScene" uid="uid://37q6vpnobpal" path="res://ui/time_trial_leaderboard.tscn" id="9_0odxb"]
[ext_resource type="PackedScene" uid="uid://d2g1ppqgwlewj" path="res://player.tscn" id="9_4c57u"]
[ext_resource type="Script" uid="uid://jcp3kan67dxe" path="res://race_course_setup.gd" id="9_setup"]
[ext_resource type="Script" uid="uid://bulnt0tdwhscf" path="res://race/player_spawner.gd" id="10_efxa6"]
[ext_resource type="PackedScene" uid="uid://wtjl8wu3i1kx" path="res://ui/time_trial_rank_panel.tscn" id="10_lswn8"]
[ext_resource type="PackedScene" uid="uid://dlmmnas6pu2eq" path="res://ui/time_trial_hud.tscn" id="11_a6jrf"]
[ext_resource type="Script" uid="uid://cnch5086mi6jc" path="res://scripts/water_animator.gd" id="12_074og"]
[ext_resource type="Material" uid="uid://b3lodrgc0thgn" path="res://materials/rain_material.tres" id="13_cegan"]
[ext_resource type="Script" uid="uid://cwg7nk8hgtnv6" path="res://scripts/weather_follow.gd" id="14_82xsv"]
[ext_resource type="Material" uid="uid://dwm513b0hacrf" path="res://materials/snow_material.tres" id="15_getpj"]
[ext_resource type="Script" uid="uid://ip5blnynhbs" path="res://scripts/grass_manager.gd" id="16_ryguw"]
[ext_resource type="PlaneMesh" uid="uid://brsm74ufeeqhs" path="res://meshes/grass_blade.tres" id="17_d13ii"]
[ext_resource type="Material" uid="uid://rgj3e8m3d37s" path="res://materials/grass_material.tres" id="18_1u8w0"]

[sub_resource type="BoxMesh" id="BoxMesh_hqp12"]
size = Vector3(100, 0.2, 100)

[sub_resource type="BoxShape3D" id="BoxShape3D_8s5kf"]
size = Vector3(100, 0.2, 100)

[sub_resource type="BoxMesh" id="BoxMesh_e7trw"]
size = Vector3(20, 1, 0.5)

[sub_resource type="BoxShape3D" id="BoxShape3D_amemp"]
size = Vector3(20, 1, 0.5)

[sub_resource type="BoxMesh" id="BoxMesh_1bvp3"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxShape3D" id="BoxShape3D_lquwl"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxMesh" id="BoxMesh_7mycd"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxShape3D" id="BoxShape3D_272bh"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxMesh" id="BoxMesh_5vw27"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxShape3D" id="BoxShape3D_kek77"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxMesh" id="BoxMesh_4c57u"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxShape3D" id="BoxShape3D_efxa6"]
size = Vector3(40, 1, 0.5)

[sub_resource type="BoxMesh" id="BoxMesh_amemp"]
size = Vector3(6, 2, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_maauo"]
size = Vector3(6, 2, 1)

[sub_resource type="BoxMesh" id="BoxMesh_maauo"]
size = Vector3(6, 2, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_la3fi"]
size = Vector3(6, 2, 1)

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_0odxb"]
sky_top_color = Color(0.22745098, 0.65882355, 1, 1)
sky_horizon_color = Color(0.8117647, 0.9098039, 1, 1)
ground_bottom_color = Color(0.16470589, 0.22745098, 0.2901961, 1)
ground_horizon_color = Color(0.8117647, 0.9098039, 1, 1)
sun_angle_max = 55.0

[sub_resource type="Sky" id="Sky_lswn8"]
sky_material = SubResource("ProceduralSkyMaterial_0odxb")

[sub_resource type="Environment" id="Environment_a6jrf"]
background_mode = 2
sky = SubResource("Sky_lswn8")
ambient_light_source = 3
glow_enabled = true
glow_intensity = 0.4

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_xuqvo"]
emission_shape = 3
emission_box_extents = Vector3(14, 0.5, 14)
direction = Vector3(0, -1, 0)
initial_velocity_min = 18.0
initial_velocity_max = 24.0
gravity = Vector3(0, -42, 0)
scale_min = 0.05
scale_max = 0.12

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_qsp4k"]
transparency = 1
shading_mode = 0
vertex_color_use_as_albedo = true
billboard_mode = 3
billboard_keep_scale = true
particles_anim_h_frames = 1
particles_anim_v_frames = 1
particles_anim_loop = false

[sub_resource type="QuadMesh" id="QuadMesh_kq58d"]
material = SubResource("StandardMaterial3D_qsp4k")
size = Vector2(0.25, 0.25)

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_seu75"]
lifetime_randomness = 0.4
emission_shape = 3
emission_box_extents = Vector3(20, 1, 20)
spread = 70.0
initial_velocity_min = 0.3
initial_velocity_max = 0.8
gravity = Vector3(0, -1.8, 0)
damping_min = 0.1
damping_max = 0.5
scale_min = 0.04
scale_max = 0.12
turbulence_enabled = true
turbulence_noise_strength = 2.0
turbulence_noise_speed = Vector3(0.8, 0.2, 0.8)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_htxhm"]
transparency = 1
shading_mode = 0
vertex_color_use_as_albedo = true
billboard_mode = 3
billboard_keep_scale = true
particles_anim_h_frames = 1
particles_anim_v_frames = 1
particles_anim_loop = false

[sub_resource type="QuadMesh" id="QuadMesh_jq2sk"]
material = SubResource("StandardMaterial3D_htxhm")
size = Vector2(0.25, 0.25)

[node name="Main" type="Node3D" unique_id=1697816867]
script = ExtResource("9_setup")

[node name="RaceMap" parent="." unique_id=1291223955 instance=ExtResource("8_map")]

[node name="Track" type="Node3D" parent="." unique_id=1364110620]
visible = false

[node name="Floor" type="StaticBody3D" parent="Track" unique_id=1579361880]

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Floor" unique_id=1187611900]
mesh = SubResource("BoxMesh_hqp12")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Floor" unique_id=2049311600]
shape = SubResource("BoxShape3D_8s5kf")

[node name="Walls" type="Node3D" parent="Track" unique_id=1425255683]

[node name="Wall1" type="StaticBody3D" parent="Track/Walls" unique_id=455882260]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, -10)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall1" unique_id=241669667]
mesh = SubResource("BoxMesh_e7trw")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall1" unique_id=864257628]
shape = SubResource("BoxShape3D_amemp")

[node name="Wall2" type="StaticBody3D" parent="Track/Walls" unique_id=1740358273]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 10)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall2" unique_id=600701840]
mesh = SubResource("BoxMesh_e7trw")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall2" unique_id=622144843]
shape = SubResource("BoxShape3D_amemp")

[node name="Wall3" type="StaticBody3D" parent="Track/Walls" unique_id=1290416735]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -10, 0.5, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall3" unique_id=2072774705]
mesh = SubResource("BoxMesh_e7trw")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall3" unique_id=2074050414]
shape = SubResource("BoxShape3D_amemp")

[node name="Wall4" type="StaticBody3D" parent="Track/Walls" unique_id=1741073821]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 10, 0.5, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall4" unique_id=1845948873]
mesh = SubResource("BoxMesh_e7trw")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall4" unique_id=1110155683]
shape = SubResource("BoxShape3D_amemp")

[node name="Wall5" type="StaticBody3D" parent="Track/Walls" unique_id=1108966794]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.69906616, 0.5, 20.049438)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall5" unique_id=636393368]
mesh = SubResource("BoxMesh_1bvp3")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall5" unique_id=1128740702]
shape = SubResource("BoxShape3D_lquwl")

[node name="Wall6" type="StaticBody3D" parent="Track/Walls" unique_id=19067156]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -20.425903, 0.5, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall6" unique_id=565969382]
mesh = SubResource("BoxMesh_7mycd")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall6" unique_id=136324871]
shape = SubResource("BoxShape3D_272bh")

[node name="Wall7" type="StaticBody3D" parent="Track/Walls" unique_id=120746226]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.6425781, 0.5, -19.974976)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall7" unique_id=1213974814]
mesh = SubResource("BoxMesh_5vw27")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall7" unique_id=333215647]
shape = SubResource("BoxShape3D_kek77")

[node name="Wall8" type="StaticBody3D" parent="Track/Walls" unique_id=522523801]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 19.060982, 0.5, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Track/Walls/Wall8" unique_id=529467876]
mesh = SubResource("BoxMesh_4c57u")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Track/Walls/Wall8" unique_id=1923567555]
shape = SubResource("BoxShape3D_efxa6")

[node name="Finish" type="Area3D" parent="." unique_id=884375151]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -14.243988, 1, -2.2565918)
visible = false
script = ExtResource("2_0xm2m")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Finish" unique_id=1492683921]
mesh = SubResource("BoxMesh_amemp")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Finish" unique_id=1233567838]
shape = SubResource("BoxShape3D_maauo")

[node name="CheckPoints" type="Node3D" parent="." unique_id=143600986]
visible = false

[node name="CheckPoint1" type="Area3D" parent="CheckPoints" unique_id=2029518838]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 13.799347, 1, 3)
script = ExtResource("4_1bvp3")

[node name="MeshInstance3D" type="MeshInstance3D" parent="CheckPoints/CheckPoint1" unique_id=1274172078]
mesh = SubResource("BoxMesh_maauo")

[node name="CollisionShape3D" type="CollisionShape3D" parent="CheckPoints/CheckPoint1" unique_id=547058015]
shape = SubResource("BoxShape3D_la3fi")

[node name="CheckPoint2" type="Area3D" parent="CheckPoints" unique_id=645931963]
transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, 0.7253723, 1, 14.977661)
script = ExtResource("4_1bvp3")
checkpoint_index = 2

[node name="MeshInstance3D" type="MeshInstance3D" parent="CheckPoints/CheckPoint2" unique_id=953197097]
mesh = SubResource("BoxMesh_maauo")

[node name="CollisionShape3D" type="CollisionShape3D" parent="CheckPoints/CheckPoint2" unique_id=1813359546]
shape = SubResource("BoxShape3D_la3fi")

[node name="UI" type="CanvasLayer" parent="." unique_id=675326437]

[node name="Dashboard" parent="UI" unique_id=2059773937 instance=ExtResource("5_getpj")]

[node name="StartCenter" parent="UI" unique_id=1143439026 instance=ExtResource("6_ryguw")]

[node name="CountdownCenter" parent="UI" unique_id=2010680389 instance=ExtResource("7_d13ii")]

[node name="FinishCenter" parent="UI" unique_id=1846302769 instance=ExtResource("8_1u8w0")]

[node name="LeaderboardPanel" parent="UI" unique_id=316614866 instance=ExtResource("9_0odxb")]

[node name="RankPanel" parent="UI" unique_id=1177923342 instance=ExtResource("10_lswn8")]

[node name="HUD" parent="UI" unique_id=669336810 instance=ExtResource("11_a6jrf")]

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="." unique_id=1279504209]
transform = Transform3D(0.8660254, 0.43301272, -0.24999999, 0, 0.49999997, 0.86602545, 0.5, -0.75, 0.43301266, 0, 0, 0)
shadow_enabled = true

[node name="RaceManager" type="Node" parent="." unique_id=1588467986]
script = ExtResource("3_h2yge")
total_checkpoints = 7

[node name="WorldEnvironment" type="WorldEnvironment" parent="." unique_id=889358878]
environment = SubResource("Environment_a6jrf")

[node name="Player" parent="." unique_id=529282143 instance=ExtResource("9_4c57u")]

[node name="Players" type="Node3D" parent="." unique_id=535527962]

[node name="PlayerSpawner" type="MultiplayerSpawner" parent="Players" unique_id=69904012]
script = ExtResource("10_efxa6")

[node name="WaterAnimator" type="Node" parent="." unique_id=471142367]
script = ExtResource("12_074og")

[node name="RainParticles" type="GPUParticles3D" parent="." unique_id=829402449]
material_override = ExtResource("13_cegan")
emitting = false
amount = 800
lifetime = 0.8
preprocess = 0.5
process_material = SubResource("ParticleProcessMaterial_xuqvo")
draw_pass_1 = SubResource("QuadMesh_kq58d")
script = ExtResource("14_82xsv")

[node name="SnowParticles" type="GPUParticles3D" parent="." unique_id=1468930010]
material_override = ExtResource("15_getpj")
emitting = false
amount = 600
lifetime = 6.0
preprocess = 3.0
process_material = SubResource("ParticleProcessMaterial_seu75")
draw_pass_1 = SubResource("QuadMesh_jq2sk")
script = ExtResource("14_82xsv")

[node name="GrassField" type="MultiMeshInstance3D" parent="." unique_id=551726256]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -55.15, -0.15, -38.12)
script = ExtResource("16_ryguw")
placement_area = Vector2(8, 8)
max_instances = 1200
grass_mesh = ExtResource("17_d13ii")
grass_material = ExtResource("18_1u8w0")

```

**player.tscn**
```ini
[gd_scene format=3 uid="uid://d2g1ppqgwlewj"]

[ext_resource type="Script" uid="uid://b60axc1opgq85" path="res://player.gd" id="1_player"]
[ext_resource type="PackedScene" uid="uid://vw54wjuncdts" path="res://Car Model/ConceptCar 050/scene.gltf" id="2_model"]

[sub_resource type="BoxMesh" id="BoxMesh_player"]
size = Vector3(1.7, 0.8, 4.3)

[sub_resource type="BoxShape3D" id="BoxShape3D_player"]
size = Vector3(1.7, 0.8, 4.3)

[node name="Player" type="VehicleBody3D" unique_id=488947988]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
mass = 900.0
center_of_mass_mode = 1
center_of_mass = Vector3(0, -0.15, 0)
can_sleep = false
continuous_cd = true
script = ExtResource("1_player")

[node name="MeshInstance3D" type="MeshInstance3D" parent="." unique_id=599318418]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.85, 0)
visible = false
mesh = SubResource("BoxMesh_player")

[node name="CollisionShape3D" type="CollisionShape3D" parent="." unique_id=901699288]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.85, 0)
shape = SubResource("BoxShape3D_player")

[node name="WheelFL" type="VehicleWheel3D" parent="." unique_id=302130219]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.0247, 0.58, -1.3)
use_as_steering = true
wheel_roll_influence = 0.02
wheel_radius = 0.38
wheel_rest_length = 0.18
wheel_friction_slip = 2.3
suspension_travel = 0.15
suspension_stiffness = 150.0
suspension_max_force = 9000.0
damping_compression = 2.0
damping_relaxation = 2.4

[node name="WheelFR" type="VehicleWheel3D" parent="." unique_id=1948605649]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.0247, 0.58, -1.3)
use_as_steering = true
wheel_roll_influence = 0.02
wheel_radius = 0.38
wheel_rest_length = 0.18
wheel_friction_slip = 2.3
suspension_travel = 0.15
suspension_stiffness = 150.0
suspension_max_force = 9000.0
damping_compression = 2.0
damping_relaxation = 2.4

[node name="WheelRL" type="VehicleWheel3D" parent="." unique_id=1072333151]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.0247, 0.58, 1.5829)
use_as_traction = true
wheel_roll_influence = 0.02
wheel_radius = 0.38
wheel_rest_length = 0.18
wheel_friction_slip = 2.3
suspension_travel = 0.15
suspension_stiffness = 150.0
suspension_max_force = 9000.0
damping_compression = 2.0
damping_relaxation = 2.4

[node name="WheelRR" type="VehicleWheel3D" parent="." unique_id=225523576]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.0247, 0.58, 1.5829)
use_as_traction = true
wheel_roll_influence = 0.02
wheel_radius = 0.38
wheel_rest_length = 0.18
wheel_friction_slip = 2.3
suspension_travel = 0.15
suspension_stiffness = 150.0
suspension_max_force = 9000.0
damping_compression = 2.0
damping_relaxation = 2.4

[node name="Camera3D" type="Camera3D" parent="." unique_id=1144676184]
transform = Transform3D(1, 0, 0, 0, 0.90630776, 0.42261827, 0, -0.42261827, 0.90630776, 0, 4, 6)
current = true

[node name="ConceptCar" parent="." unique_id=1987842562 instance=ExtResource("2_model")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0.32, 0)
```

### scenes

**grass_blade.tscn**
```ini
[gd_scene format=3 uid="uid://grass_blade_mesh"]

[node name="GrassBlade" type="MeshInstance3D" parent="."]
mesh = SubResource("PlaneMesh_7mycd")
material_override = ExtResource("res://shaders/grass.gdshader")

[sub_resource type="PlaneMesh" id="PlaneMesh_7mycd"]
size = Vector2(0.1, 0.5)
```

**water_surface.tscn**
```ini
[gd_scene format=3 uid="uid://water_surface"]

[node name="WaterSurface" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
script = ExtResource("res://scripts/water_surface.gd")
mesh = SubResource("PlaneMesh_5vw27")
material_override = ExtResource("res://shaders/water.gdshader")

[sub_resource type="PlaneMesh" id="PlaneMesh_5vw27"]
size = Vector2(50, 50)

```

### ui

**dashboard.tscn**
```ini
[gd_scene format=3 uid="uid://bq4bfthd7tmdf"]

[ext_resource type="Script" uid="uid://fhnpgubqq5bv" path="res://dashboard.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]

[node name="Dashboard" type="Control" unique_id=2059773937]
layout_mode = 3
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -316.0
offset_top = -206.0
offset_right = -16.0
offset_bottom = -16.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")

```

**lobby.tscn**
```ini
[gd_scene format=3 uid="uid://bjd51o1dxv34p"]

[ext_resource type="Script" uid="uid://cvbs3fvs00cuk" path="res://ui/lobby_ui.gd" id="1_nmq56"]

[node name="LobbyUI" type="Control" unique_id=762808719]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_nmq56")

```

**time_trial_countdown.tscn**
```ini
[gd_scene format=3 uid="uid://cvei4o6n8fc4a"]

[ext_resource type="Script" uid="uid://dbscqudl31rtp" path="res://ui/time_trial_countdown.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]

[node name="CountdownCenter" type="CenterContainer" unique_id=2010680389]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")

[node name="CountdownLabel" type="Label" parent="." unique_id=1632728288]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.6666667)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 110
text = "3"
horizontal_alignment = 1

```

**time_trial_finish_screen.tscn**
```ini
[gd_scene format=3 uid="uid://gloiakrmjtp4"]

[ext_resource type="Script" uid="uid://nbsmht2damso" path="res://ui/time_trial_finish_screen.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]
[ext_resource type="Script" uid="uid://da3fqfqv6gtgm" path="res://addons/godot_ai/runtime/draw_recipe.gd" id="3_sfcax"]

[node name="FinishCenter" type="CenterContainer" unique_id=1846302769]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")

[node name="FinishPanel" type="PanelContainer" parent="." unique_id=292149144]
layout_mode = 2

[node name="VBoxContainer" type="VBoxContainer" parent="FinishPanel" unique_id=162524990]
layout_mode = 2

[node name="FinishTitle" type="Label" parent="FinishPanel/VBoxContainer" unique_id=725595107]
layout_mode = 2
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.73333335)
theme_override_colors/font_outline_color = Color(0.03137255, 0.1254902, 0.1882353, 1)
theme_override_constants/outline_size = 10
theme_override_font_sizes/font_size = 84
text = "完成！"
horizontal_alignment = 1

[node name="FinalTimeLabel" type="Label" parent="FinishPanel/VBoxContainer" unique_id=221642022]
layout_mode = 2
theme_override_font_sizes/font_size = 34
text = "成績：0.00 秒"
horizontal_alignment = 1

[node name="NewRecordLabel" type="Label" parent="FinishPanel/VBoxContainer" unique_id=1395201345]
visible = false
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.8352941, 0.2901961, 1)
theme_override_font_sizes/font_size = 28
text = "★ 新紀錄！"
horizontal_alignment = 1

[node name="RestartHintLabel" type="Label" parent="FinishPanel/VBoxContainer" unique_id=2010031906]
layout_mode = 2
theme_override_colors/font_color = Color(0.54509807, 0.63529414, 0.7019608, 1)
theme_override_font_sizes/font_size = 20
text = "按 R 重新挑戰"
horizontal_alignment = 1

[node name="NextPlayerButton" type="Button" parent="FinishPanel/VBoxContainer" unique_id=1675024247]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 28
text = "下一位玩家"

[node name="HomeButton" type="Button" parent="FinishPanel/VBoxContainer" unique_id=1597454312]
unique_name_in_owner = true
custom_minimum_size = Vector2(64, 64)
layout_mode = 2
theme_override_font_sizes/font_size = 28

[node name="HomeIcon" type="Control" parent="FinishPanel/VBoxContainer/HomeButton" unique_id=1673572602]
anchors_preset = 0
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("3_sfcax")
metadata/_ops = [{
"color": Color(0.101960786, 0.81960785, 1, 1),
"draw": "polygon",
"points": PackedVector2Array(32, 8, 8, 30, 56, 30)
}, {
"color": Color(0.9098039, 0.96862745, 1, 1),
"draw": "rect",
"rect": Rect2(16, 30, 32, 24)
}, {
"color": Color(0.101960786, 0.81960785, 1, 1),
"draw": "rect",
"rect": Rect2(27, 42, 10, 12)
}]

```

**time_trial_hud.tscn**
```ini
[gd_scene format=3 uid="uid://dlmmnas6pu2eq"]

[ext_resource type="Script" uid="uid://dti1u6bq7jd1s" path="res://ui/time_trial_hud.gd" id="1_script"]

[node name="HUD" type="PanelContainer" unique_id=669336810]
visible = false
offset_left = 20.0
offset_top = 20.0
offset_right = 320.0
offset_bottom = 210.0
mouse_filter = 2
script = ExtResource("1_script")

[node name="Margin" type="MarginContainer" parent="." unique_id=383563868]
layout_mode = 2
theme_override_constants/margin_left = 18
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 18
theme_override_constants/margin_bottom = 12

[node name="VBox" type="VBoxContainer" parent="Margin" unique_id=853456886]
layout_mode = 2
theme_override_constants/separation = 4

[node name="TimerLabel" type="Label" parent="Margin/VBox" unique_id=887863019]
layout_mode = 2
theme_override_colors/font_color = Color(0.101960786, 0.8156863, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.6666667)
theme_override_font_sizes/font_size = 40
text = "0.00"

[node name="CheckpointLabel" type="Label" parent="Margin/VBox" unique_id=135447600]
layout_mode = 2
theme_override_colors/font_color = Color(0.8117647, 0.89411765, 0.9411765, 1)
theme_override_font_sizes/font_size = 20
text = "檢查點：0 / 7"

[node name="BestTimeLabel" type="Label" parent="Margin/VBox" unique_id=682810081]
layout_mode = 2
theme_override_colors/font_color = Color(0.54509807, 0.63529414, 0.7019608, 1)
theme_override_font_sizes/font_size = 18
text = "最佳：--"

[node name="CheckpointBar" type="ProgressBar" parent="Margin/VBox" unique_id=1845139897]
custom_minimum_size = Vector2(240, 8)
layout_mode = 2
max_value = 7.0
show_percentage = false

```

**time_trial_leaderboard.tscn**
```ini
[gd_scene format=3 uid="uid://37q6vpnobpal"]

[ext_resource type="Script" uid="uid://orswd61k0fbt" path="res://ui/time_trial_leaderboard.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]

[node name="LeaderboardPanel" type="PanelContainer" unique_id=316614866]
anchors_preset = 11
anchor_left = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -380.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = -16.0
grow_horizontal = 0
theme = ExtResource("2_theme")
script = ExtResource("1_script")

[node name="Margin" type="MarginContainer" parent="." unique_id=107833831]
layout_mode = 2
theme_override_constants/margin_left = 18
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 18
theme_override_constants/margin_bottom = 12

[node name="LeaderboardVBox" type="VBoxContainer" parent="Margin" unique_id=2044937576]
layout_mode = 2
theme_override_constants/separation = 10

[node name="LeaderboardTitle" type="Label" parent="Margin/LeaderboardVBox" unique_id=1394995699]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.73333335)
theme_override_colors/font_outline_color = Color(0.03137255, 0.1254902, 0.1882353, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 32
text = "排行榜"
horizontal_alignment = 1

[node name="TabBar" type="HBoxContainer" parent="Margin/LeaderboardVBox" unique_id=1224583859]
layout_mode = 2
theme_override_constants/separation = 8
alignment = 1

[node name="LocalTab" type="Button" parent="Margin/LeaderboardVBox/TabBar" unique_id=1552220672]
unique_name_in_owner = true
custom_minimum_size = Vector2(140, 0)
layout_mode = 2
text = "本地"

[node name="PublicTab" type="Button" parent="Margin/LeaderboardVBox/TabBar" unique_id=819929320]
unique_name_in_owner = true
custom_minimum_size = Vector2(140, 0)
layout_mode = 2
text = "公開"

[node name="LeaderboardGrid" type="GridContainer" parent="Margin/LeaderboardVBox" unique_id=673791644]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/h_separation = 8
theme_override_constants/v_separation = 6
columns = 3

[node name="PublicLeaderboardGrid" type="GridContainer" parent="Margin/LeaderboardVBox" unique_id=1477704821]
unique_name_in_owner = true
visible = false
layout_mode = 2
theme_override_constants/h_separation = 8
theme_override_constants/v_separation = 6
columns = 3

```

**time_trial_rank_panel.tscn**
```ini
[gd_scene format=3 uid="uid://wtjl8wu3i1kx"]

[ext_resource type="Script" uid="uid://bfbpi4d25jog8" path="res://race/rank_panel.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]

[node name="RankPanel" type="PanelContainer" unique_id=1177923342]
visible = false
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -244.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 352.0
theme = ExtResource("2_theme")
script = ExtResource("1_script")

```

**time_trial_start_screen.tscn**
```ini
[gd_scene format=3 uid="uid://b1piyf2oecvnn"]

[ext_resource type="Script" uid="uid://cyg05oxg0je4" path="res://ui/time_trial_start_screen.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://ddikhtgjr7xbc" path="res://ui/race_theme.tres" id="2_theme"]
[ext_resource type="Script" uid="uid://btounhqdr632d" path="res://ui/menu_tabs.gd" id="3_tabs"]

[node name="StartCenter" type="Control" unique_id=1143439026]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")

[node name="TitleVBox" type="VBoxContainer" parent="." unique_id=2069064974]
layout_mode = 0
offset_left = 32.0
offset_top = 16.0
offset_right = 320.0
offset_bottom = 76.0

[node name="TitleLabel" type="Label" parent="TitleVBox" unique_id=17213208]
layout_mode = 2
theme_override_colors/font_color = Color(0.95686275, 0.9843137, 0.99607843, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.73333335)
theme_override_colors/font_outline_color = Color(0.03137255, 0.1254902, 0.1882353, 1)
theme_override_constants/outline_size = 10
theme_override_font_sizes/font_size = 48
text = "3D Race"

[node name="MainCard" type="VBoxContainer" parent="." unique_id=690793920]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -540.0
offset_top = 80.0
offset_right = 180.0
offset_bottom = 680.0
grow_horizontal = 2
theme_override_constants/separation = 0
script = ExtResource("3_tabs")

[node name="TabHeader" type="HBoxContainer" parent="MainCard" unique_id=179119929]
custom_minimum_size = Vector2(0, 80)
layout_mode = 2
theme_override_constants/separation = 2

[node name="LoginButton" type="Button" parent="MainCard/TabHeader" unique_id=1872933768]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 28
toggle_mode = true
text = "登入"

[node name="RegisterButton" type="Button" parent="MainCard/TabHeader" unique_id=1323330474]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 28
toggle_mode = true
text = "註冊"

[node name="PlayButton" type="Button" parent="MainCard/TabHeader" unique_id=1727377975]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 28
toggle_mode = true
text = "體驗"

[node name="ContentArea" type="PanelContainer" parent="MainCard" unique_id=1128601364]
layout_mode = 2
size_flags_vertical = 3

[node name="Margin" type="MarginContainer" parent="MainCard/ContentArea" unique_id=653440309]
layout_mode = 2
theme_override_constants/margin_left = 40
theme_override_constants/margin_top = 40
theme_override_constants/margin_right = 40
theme_override_constants/margin_bottom = 40

[node name="ContentStack" type="Control" parent="MainCard/ContentArea/Margin" unique_id=1978280440]
layout_mode = 2

[node name="LoginPage" type="Control" parent="MainCard/ContentArea/Margin/ContentStack" unique_id=1560748299]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="LoginCenter" type="CenterContainer" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage" unique_id=1518915061]
layout_mode = 0
anchor_right = 1.0
anchor_bottom = 1.0

[node name="LoginContent" type="VBoxContainer" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter" unique_id=908881220]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_constants/separation = 12

[node name="Title" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=840722751]
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "使用帳號登入"
horizontal_alignment = 1

[node name="Description" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=92650372]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.5803922, 0.6392157, 0.72156864, 1)
text = "連結帳號，同步公開排行與賽事紀錄。"
horizontal_alignment = 1

[node name="EpicLoginButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=1538482787]
custom_minimum_size = Vector2(360, 48)
layout_mode = 2
tooltip_text = "透過 Epic Account Portal 驗證身份"
text = "使用 Epic Games 登入"

[node name="DiscordLoginButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=1713389993]
custom_minimum_size = Vector2(360, 48)
layout_mode = 2
tooltip_text = "透過 Discord OAuth 驗證身份"
text = "使用 Discord 帳號登入"

[node name="GoogleLoginButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=1465790570]
custom_minimum_size = Vector2(360, 48)
layout_mode = 2
tooltip_text = "Google 登入尚未設定"
disabled = true
text = "使用 Google 帳號登入"

[node name="ProviderSeparator" type="HSeparator" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=1723828287]
layout_mode = 2

[node name="ProviderNotice" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=169236364]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.39215687, 0.45490196, 0.54509807, 1)
theme_override_font_sizes/font_size = 12
text = "Google 登入準備中；登入即同意條款與隱私政策。"
horizontal_alignment = 1

[node name="AuthStatus" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent" unique_id=701369253]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.21960784, 0.7411765, 0.972549, 1)
horizontal_alignment = 1

[node name="RegisterPage" type="Control" parent="MainCard/ContentArea/Margin/ContentStack" unique_id=343913101]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="RegisterCenter" type="CenterContainer" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage" unique_id=1898206304]
layout_mode = 0
anchor_right = 1.0
anchor_bottom = 1.0

[node name="RegisterContent" type="VBoxContainer" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter" unique_id=1983041863]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_constants/separation = 10

[node name="Title" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=631453724]
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "建立遊戲身份"
horizontal_alignment = 1

[node name="Description" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=1512399647]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.5803922, 0.6392157, 0.72156864, 1)
text = "選擇帳號提供者，設定賽車暱稱。"
horizontal_alignment = 1

[node name="RegisterProviderRow" type="HBoxContainer" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=370751166]
layout_mode = 2
theme_override_constants/separation = 8

[node name="EpicRegisterButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegisterProviderRow" unique_id=1131392970]
custom_minimum_size = Vector2(112, 32)
layout_mode = 2
text = "Epic"

[node name="DiscordRegisterButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegisterProviderRow" unique_id=1871498778]
custom_minimum_size = Vector2(112, 32)
layout_mode = 2
text = "Discord"

[node name="GoogleRegisterButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegisterProviderRow" unique_id=1550227397]
custom_minimum_size = Vector2(112, 32)
layout_mode = 2
tooltip_text = "Google 登入尚未設定"
disabled = true
text = "Google"

[node name="ProfileSeparator" type="HSeparator" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=1212155314]
layout_mode = 2

[node name="UsernameInput" type="LineEdit" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=1359817275]
custom_minimum_size = Vector2(360, 38)
layout_mode = 2
placeholder_text = "公開使用者名稱（可沿用體驗模式姓名）"
max_length = 24

[node name="TermsCheckBox" type="CheckBox" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=1252664335]
layout_mode = 2
text = "我同意服務條款與隱私政策"

[node name="CreateAccountButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=531760005]
custom_minimum_size = Vector2(360, 44)
layout_mode = 2
tooltip_text = "請先完成社群帳號驗證並同意條款"
disabled = true
text = "創建帳號並開始比賽"

[node name="RegistrationNotice" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=587934200]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.39215687, 0.45490196, 0.54509807, 1)
theme_override_font_sizes/font_size = 12
text = "不建立密碼，本遊戲不保存認證資料。"
horizontal_alignment = 1

[node name="RegistrationStatus" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent" unique_id=1582345914]
custom_minimum_size = Vector2(360, 0)
layout_mode = 2
theme_override_colors/font_color = Color(0.21960784, 0.7411765, 0.972549, 1)
horizontal_alignment = 1

[node name="PlayPage" type="Control" parent="MainCard/ContentArea/Margin/ContentStack" unique_id=1854839966]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="PlayCenter" type="CenterContainer" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage" unique_id=588340642]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="ContentVBox" type="VBoxContainer" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter" unique_id=13167395]
layout_mode = 2
theme_override_constants/separation = 20

[node name="NameInput" type="LineEdit" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox" unique_id=82302346]
custom_minimum_size = Vector2(0, 50)
layout_mode = 2
theme_override_font_sizes/font_size = 24
placeholder_text = "請輸入姓名"

[node name="HintLabel" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox" unique_id=123939682]
layout_mode = 2
theme_override_colors/font_color = Color(0.43529412, 0.52156866, 0.5882353, 1)
theme_override_font_sizes/font_size = 16
text = "WASD 駕駛 · R 重置 · 通過 7 個檢查點後衝向終點"
horizontal_alignment = 1

[node name="SubtitleLabel" type="Label" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox" unique_id=1343459088]
layout_mode = 2
theme_override_colors/font_color = Color(0.101960786, 0.8156863, 1, 1)
theme_override_font_sizes/font_size = 20
text = "── TIME ATTACK ──"
horizontal_alignment = 1

[node name="Footer" type="Control" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox" unique_id=569177323]
custom_minimum_size = Vector2(0, 60)
layout_mode = 2

[node name="StartButton" type="Button" parent="MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/Footer" unique_id=1251643359]
custom_minimum_size = Vector2(160, 60)
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -160.0
offset_top = -60.0
grow_horizontal = 0
grow_vertical = 0
theme_override_font_sizes/font_size = 32
text = "開始"

```

