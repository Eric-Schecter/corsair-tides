extends Node2D

const Art=preload("res://scripts/art.gd")
const W=640.0
const H=360.0
const MAP_NAMES=["EMERALD KEYS", "STORM STRAIT", "CORSAIR REEF"]
const CLASSES=["BRIG", "TENDER", "ARTIFICER", "CUTTER", "FRIGATE", "FIRESHIP"]
const CLASS_DESC=["OAK BULWARK / BRACE AGAINST ENEMY FIRE", "SHIPWRIGHT / REPAIR THE HULL AT SEA", "GUN RAFT / DEPLOY A FLOATING BATTERY", "FULL SAIL / OUTRUN THE PIRATE FLEET", "GUN CREWS / SEVEN SECONDS OF FREE FIRE", "GREEK FIRE / IGNITE NEARBY CORSAIRS"]
const WEAPONS=["BOW CANNON", "GRAPESHOT", "SWIVEL GUN", "LONG NINE"]
const DAMAGE=[42.0,18.0,23.0,90.0]
const CADENCE=[.38,.75,.14,.85]
const INK=Color("315f73")
const TEXT=Color("fff2d1")
const CREAM=Color("fff0ce")
const GOLD=Color("f3c34f")
const MINT=Color("92eada")
var upgrades=preload("res://scripts/voyage_upgrades.gd").new()
var ui_styles:Dictionary={}
var perf_draw_us=0
var perf_draw_count=0
var perf_update_us=0
var perf_update_count=0
var terrain_canvas:Node2D
var creature_atlases:Dictionary={}
var title_shape_atlas:ImageTexture
var title_detail=false
var crisp_ship=false
# Diagnostic A/B switch, used only with a performance test.
var legacy_render=OS.get_cmdline_user_args().has("--perf-legacy") and (OS.get_cmdline_user_args().has("--perf-test") or OS.get_cmdline_user_args().has("--perf-stress"))
var ellipse_meshes:Dictionary={}
var bake_creature=""
var tier_gallery=false
var shape_atlas:ImageTexture
var terrain_layers:Array=[]
var sea_color:Color
var font:Font
var map_texture:ImageTexture
var chart_cache:Dictionary={}
var mini_texture:ImageTexture
var obstacles:Array[Rect2]=[]
var props:Array=[]
var ship_icons:Array=[]
var hulls:Array=[]
var enemy_hull:ImageTexture
var land_polygons:Array=[]
var navigation:AStarGrid2D
var navigation_cache:Dictionary={}
var shot_direction=Vector2.RIGHT
var sea_strokes:Array=[]
var render_offset=Vector2.ZERO
var heading=-PI/2
var velocity=Vector2.ZERO
var wake_history:Array=[]
var wake_clock=0.0
var bgm:AudioStreamPlayer
var water_player:AudioStreamPlayer
var water_gain=0.0
var player=Vector2(620,1010)
var cam=Vector2(620,1010)
var aim=Vector2.RIGHT
var last_move=Vector2.DOWN
var cursor=Vector2(420,180)
var moving=false
var hp=100.0
var armor=100.0
var kills=0
var level=1
var xp=0
var wave=0
var map_id=0
var unlocked=0
var class_id=0
var state="menu"
var old_state="play"
var weapon=0
var owned=[true,false,false,false]
var bullets:Array=[]
var enemies:Array=[]
var corpses:Array=[]
var particles:Array=[]
var combat_fx:Array=[]
var floats:Array=[]
var pickups:Array=[]
var turrets:Array=[]
var buttons:Array=[]
var ui_panel_bounds:Array[Rect2]=[]
var clock=0.0
var elapsed=0.0
var shot_cd=0.0
var dodge_left=0.0
var dodge_cd=0.0
var invulnerable=0.0
var skill_cd=0.0
var skill_buff=0.0
var clearing=false
const CLEAR_DROP_CHANCE=.02
var shake=0.0
var muzzle=0.0
var hitflash=0.0
var wave_left=0
var spawn_clock=0.0
var simulation_accumulator=0.0
var music_muted=false
var wave_timer=0.0
var message=""
var message_left=0.0
var boss_spawned=false
var boss_alive=false
var total_damage=0.0
var damage_boost=1.0
var speed_boost=1.0
var max_hp=100.0
var rng=RandomNumberGenerator.new()
var sounds={}
var voices:Array[AudioStreamPlayer]=[]
var audio_index=0
var sound_last:Dictionary={}
var sound_rng=RandomNumberGenerator.new()
var muted=false
var capture_mode=false
var test_mode=false
var test_failures=0

func _ready():
 for key in ["octopus","octopus_coral","jellyfish","crab","ship","octopus_hit","octopus_coral_hit","jellyfish_hit","crab_hit","octopus_down","octopus_coral_down","jellyfish_down","crab_down"]:
  var path="res://assets/creatures/%s.png"%key
  if ResourceLoader.exists(path):creature_atlases[key]=load(path)
 rng.seed=24893
 font=SystemFont.new()
 font.font_names=PackedStringArray(["Avenir Next", "Nunito", "DejaVu Sans", "sans-serif"])
 font.font_weight=600
 for job in range(6):
  var icon=Art.ship_thumb(job)
  ship_icons.append([icon,icon]);hulls.append(Art.hull(job))
 enemy_hull=Art.hull(0,true)
 generate_map()
 make_audio()
 bgm=preload("res://scripts/background_music.gd").new();add_child(bgm)
 var save=ConfigFile.new()
 if save.load("user://corsair-voyage.cfg")==OK:unlocked=int(save.get_value("progress","maps",0))
 unlocked=2 # All sea regions are available in continuous survival.
 var args=OS.get_cmdline_user_args()
 capture_mode="--capture" in args
 test_mode="--self-test" in args
 if test_mode:call_deferred("self_test")
 if capture_mode:call_deferred("capture_run")
 if "--upgrade-check" in args:call_deferred("upgrade_check")
 if "--combo-demo" in args:call_deferred("combo_demo")
 if "--weapon-demo" in args:call_deferred("weapon_demo")
 if "--bake-enemies" in args:call_deferred("bake_enemies")
 if "--tier-gallery" in args:call_deferred("capture_tier_gallery")
 if "--tier-demo" in args:call_deferred("tier_demo")
 if "--controls-check" in args:call_deferred("controls_check")
 if "--no-port-check" in args:call_deferred("no_port_check")
 if "--signature-check" in args:call_deferred("signature_check")
 if "--signature-demo" in args or "--fire-demo" in args:call_deferred("signature_demo")
 if "--pressure-demo" in args:call_deferred("pressure_demo")
 if "--mount-check" in args:call_deferred("mount_check")
 if "--bgm-check" in args:call_deferred("bgm_check")
 if "--combo-check" in args:call_deferred("combo_check")
 if "--identity-check" in args:call_deferred("identity_check")
 if "--loadout-check" in args:call_deferred("loadout_check")
 if "--fx-check" in args:call_deferred("fx_check")
 if "--audio-check" in args:call_deferred("audio_check")
 if "--map-load-test" in args:call_deferred("map_load_test")
 if "--perf-stress" in args:call_deferred("perf_stress")
 if "--perf-test" in args:call_deferred("perf_test")
 if "--fresh-start-capture" in args:call_deferred("fresh_start_capture")
 if "--enemy-motion-capture" in args or "--octopus-capture" in args or "--jellyfish-capture" in args or "--crab-capture" in args:call_deferred("enemy_motion_capture")

func cache_terrain():
 if not terrain_canvas:
  terrain_canvas=preload("res://scripts/terrain_layer.gd").new()
  terrain_canvas.z_index=-10
  add_child(terrain_canvas)
 terrain_canvas.configure(terrain_layers,sea_color)


func generate_map():
 var result=Art.world(map_id)
 terrain_layers=result.layers;sea_color=result.deep
 cache_terrain()
 if not chart_cache.has(map_id):chart_cache[map_id]=ImageTexture.create_from_image(result.image)
 map_texture=chart_cache[map_id]
 obstacles=result.obstacles;land_polygons=result.land;sea_strokes=result.waves
 mini_texture=chart_cache[map_id]
 props=result.palms+result.rocks
 props.append({"p":Vector2(475,1015),"type":"port"})
 props.append({"p":Vector2(1430,230),"type":"lighthouse"})
 for p in [Vector2(240,940),Vector2(283,1000),Vector2(217,1057)]:props.append({"p":p,"type":"house"})
 for p in [Vector2(423,880),Vector2(849,1030),Vector2(1280,260),Vector2(720,1310)]:
  if not solid(p,3):props.append({"p":p,"type":"buoy"})
 if navigation_cache.has(map_id):navigation=navigation_cache[map_id]
 else:
  navigation=AStarGrid2D.new();navigation.region=Rect2i(0,0,60,60)
  navigation.cell_size=Vector2(32,32);navigation.offset=Vector2(16,16)
  navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
  navigation.update()
  for y in range(60):
   for x in range(60):navigation.set_point_solid(Vector2i(x,y),solid(Vector2(x*32+16,y*32+16),28))
  navigation_cache[map_id]=navigation

func navigation_cell(p:Vector2)->Vector2i:
 var cell=Vector2i((p-Vector2(16,16))/32).clamp(Vector2i.ZERO,Vector2i(59,59))
 if not navigation.is_point_solid(cell):return cell
 var best=cell;var distance=INF
 for y in range(maxi(0,cell.y-3),mini(60,cell.y+4)):
  for x in range(maxi(0,cell.x-3),mini(60,cell.x+4)):
   var id=Vector2i(x,y)
   if navigation.is_point_solid(id):continue
   var dist=navigation.get_point_position(id).distance_squared_to(p)
   if dist<distance:distance=dist;best=id
 return best

func clear_water_line(a:Vector2,b:Vector2,r:float=14)->bool:
 var steps=maxi(1,ceili(a.distance_to(b)/22))
 for i in range(1,steps+1):
  if solid(a.lerp(b,float(i)/steps),r):return false
 return true

func cannon_bearing()->Vector2:
 if weapon!=1:return aim
 var broadside=heading+(PI/2 if Vector2.from_angle(heading).cross(aim)>=0 else -PI/2)
 return Vector2.from_angle(broadside+clampf(angle_difference(broadside,aim.angle()),-.5,.5))

func reset_run():
 class_id=0
 upgrades.reset()
 clearing=false
 player=Vector2(620,1010);cam=player;hp=100;armor=100;max_hp=100
 heading=-PI/2;velocity=Vector2.ZERO;wake_history.clear();wake_clock=0
 kills=0;level=1;xp=0;wave=0;elapsed=0
 weapon=0;owned=[true,false,false,false]
 enemies.clear();bullets.clear();corpses.clear();combat_fx.clear();particles.clear();pickups.clear();turrets.clear();floats.clear()
 shot_cd=0;skill_cd=0;dodge_cd=0;skill_buff=0;invulnerable=0;dodge_left=0;damage_boost=1;speed_boost=1
 state="play";wave=1;wave_left=0;spawn_clock=1.5;simulation_accumulator=0;boss_alive=false;boss_spawned=false
 notify("EXPLORE THE SEA / AUTO FIRE READY")


func solid(p:Vector2,r:float=14)->bool:
 if p.x<24+r or p.y<24+r or p.x>1876-r or p.y>1876-r:return true
 for i in range(land_polygons.size()):
  if not obstacles[i].grow(r).has_point(p):continue
  for d in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
   if Geometry2D.is_point_in_polygon(p+d,land_polygons[i]):return true
 return false

func move_body(p:Vector2,v:Vector2,r:float=14)->Vector2:
 var n=p+Vector2(v.x,0)
 if not solid(n,r):p=n
 n=p+Vector2(0,v.y)
 if not solid(n,r):p=n
 return p

func _input(e):
 if e is InputEventMouse:cursor=e.position

func _unhandled_input(e):
 if e is InputEventKey and e.pressed and not e.echo:
  var k=e.keycode
  if state=="upgrade" and k>=KEY_1 and k<=KEY_3:upgrades.choose(self,k-KEY_1);return
  if k==KEY_M:music_muted=not music_muted
  if k==KEY_ESCAPE:
   if state=="pause":state=old_state
   elif state in ["play","intermission","extract"]:old_state=state;state="pause"
  if state in ["play","intermission","extract"]:
   # No temporary sailing boost; movement speed stays predictable.
   # Ship abilities are now automatic run upgrades.
   if k>=KEY_1 and k<=KEY_4 and owned[k-KEY_1]:weapon=k-KEY_1
   if k==KEY_E and state=="extract" and player.distance_to(Vector2(1280,260))<100:victory()
  elif state=="menu" and k in [KEY_ENTER,KEY_SPACE]:reset_run()
 if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
  cursor=e.position
  for b in buttons:
   if b.rect.has_point(e.position):action(b.id);get_viewport().set_input_as_handled();return

func action(id:String):
 sfx("ui")
 if id.begins_with("upgrade"):upgrades.choose(self,int(id.trim_prefix("upgrade")));return
 if id=="play":reset_run()
 elif id=="start":reset_run()
 elif id=="back":state="menu"
 elif id.begins_with("map"):
  var n=int(id.trim_prefix("map"))
  if n<=unlocked and n!=map_id:map_id=n;generate_map()
 elif id=="music":music_muted=not music_muted
 elif id.begins_with("cannon"):
  var cannon=int(id.trim_prefix("cannon"))
  if state=="play" and cannon>=0 and cannon<4 and owned[cannon]:weapon=cannon;sfx("ui")
 elif id=="resume":state=old_state
 elif id=="menu":state="menu"
 elif id=="retry":reset_run()
 elif id=="next":map_id=mini(map_id+1,2);generate_map();reset_run()

func _process(dt):
 var perf_start=Time.get_ticks_usec()
 if state not in ["pause","upgrade"]:
  clock+=dt;message_left=maxf(0,message_left-dt)
 if state in ["play","intermission","extract"]:
  simulation_accumulator+=minf(dt,.15)
  while simulation_accumulator>=1.0/60 and state in ["play","intermission","extract"]:
   simulation_accumulator-=1.0/60
   update_game(1.0/60)
 else:simulation_accumulator=0
 update_water_audio(dt)
 if bgm:bgm.update_mix(state,muted or music_muted,test_mode,dt)
 perf_update_us+=Time.get_ticks_usec()-perf_start;perf_update_count+=1
 queue_redraw()

func sail(direction:Vector2,dt:float):
 if direction.length()>0:
  last_move=direction
  heading=rotate_toward(heading,direction.angle(),dt*8.0)
 var forward=Vector2.from_angle(heading)
 var speed=88*speed_boost*(1.2 if class_id==3 else 1.0)*(1.5 if skill_buff>0 and class_id==3 else 1.0)
 var target=direction.normalized()*speed if direction.length()>0 else Vector2.ZERO

 velocity=velocity.move_toward(target,dt*(400 if direction.length()>0 else 450))
 moving=velocity.length()>8
 var old=player
 player=move_body(player,velocity*dt)
 if abs(player.x-old.x)<.001:velocity.x*=.8
 if abs(player.y-old.y)<.001:velocity.y*=.8
 for w in wake_history:w.age+=dt
 wake_history=wake_history.filter(func(w):return w.age<2.5)
 wake_clock-=dt
 if moving and wake_clock<=0:
  wake_clock=.045
  wake_history.append({"p":player-forward*25,"dir":forward,"age":0.0,"strength":minf(1,velocity.length()/85)})

func update_game(dt:float):
 elapsed+=dt
 shot_cd=maxf(0,shot_cd-dt);muzzle=maxf(0,muzzle-dt);dodge_cd=maxf(0,dodge_cd-dt);dodge_left=maxf(0,dodge_left-dt)
 invulnerable=maxf(0,invulnerable-dt);skill_cd=maxf(0,skill_cd-dt);skill_buff=maxf(0,skill_buff-dt)
 shake=maxf(0,shake-dt*15);hitflash=maxf(0,hitflash-dt)
 var direction=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
 sail(direction,dt)
 cam=cam.lerp(player,1.0-exp(-dt*9));cam=cam.clamp(Vector2(320,180),Vector2(1580,1720))
 auto_attack()
 if state=="play":
  spawn_clock-=dt
  wave=1+int(elapsed/45) # Internal difficulty only; there are no wave transitions.
  if spawn_clock<=0:
   # Keep the spawn clock running at capacity; never accumulate a backlog.
   spawn_clock+=maxf(.24,.95-elapsed/300)
   if enemies.size()<mini(32,18+int(elapsed/10)):spawn_enemy()
 update_enemies(dt);update_bullets(dt);update_effects(dt)
 upgrades.tick(self,dt)
 for t in turrets:
  t.life-=dt;t.cd-=dt
  if t.cd<=0 and not enemies.is_empty():
   var target=nearest_enemy(t.p)
   if target.distance_to(t.p)>170 or not clear_water_line(t.p,target,3):continue
   bullets.append({"p":t.p,"v":(target-t.p).normalized()*510,"life":.35,"dmg":21.0*damage_boost,"pierce":false,"gun":2});t.cd=.17;sfx("smg")
 turrets=turrets.filter(func(t):return t.life>0)
 for i in range(pickups.size()-1,-1,-1):
  var p=pickups[i]
  if p.p.distance_to(player)<48+int(upgrades.ranks.get("magnet",0))*30:p.p=p.p.move_toward(player,dt*170)
  if p.p.distance_to(player)<12:
   pickups.remove_at(i)
   if p.type=="xp":upgrades.gain(self,int(p.value))
   elif p.type=="clear":release_firework()
   elif p.type=="health":hp=minf(max_hp,hp+int(p.value))
   elif p.type=="armor":armor=minf(100,armor+int(p.value))
   collect_feedback(p.type,p.value)
 upgrades.offer(self)
 if state=="extract" and player.distance_to(Vector2(1280,260))<57:victory()

func nearest_enemy(p:Vector2)->Vector2:
 var nearest=Vector2.ZERO;var dist=INF
 for e in enemies:
  var d=e.p.distance_squared_to(p)
  if d<dist:dist=d;nearest=e.p
 return nearest

func spawn_enemy(boss=false):
 var p=player
 for attempt in range(45):
  var a=rng.randf()*TAU
  p=(player+Vector2.from_angle(a)*rng.randf_range(245,320)).clamp(Vector2(30,30),Vector2(1870,1870))
  if not solid(p,12) and p.distance_to(player)>210:break
 if solid(p,12):p=Vector2(620,player.y-240).clamp(Vector2(30,30),Vector2(1870,1870))
 var kind=rng.randi_range(1,7)
 var health=85+int(elapsed*.42)+map_id*15
 if boss:kind=9;health=1700+map_id*600;boss_alive=true;notify("DREADNOUGHT / WATCH FOR THE BROADSIDE");sfx("boss")
 enemies.append({"p":p,"hp":float(health),"max":float(health),"kind":kind,"speed":rng.randf_range(30,42)+minf(22,elapsed*.07)+(14 if kind==4 else 0),"flash":0.0,"attack":0.0,"boss":boss,"phase":rng.randf()*TAU,"knock":Vector2.ZERO,"charge":0.0,"charge_v":Vector2.ZERO,"heading":(player-p).angle(),"fire_cd":rng.randf_range(1.5,3.5),"muzzle":0.0,"route":PackedVector2Array(),"route_cd":rng.randf_range(.05,.5),"sight":true,"windup":0.0,"recover":0.0,"hit_pose":0.0,"attack_dir":Vector2.RIGHT,"anim_clock":rng.randf()*TAU,"dash_left":0.0,"species":(["ship","octopus","jellyfish","crab"][kind%4] if not boss else "ship")})

func update_enemies(dt:float):
 var buckets:Dictionary={}
 for j in range(enemies.size()):
  var cell=Vector2i(floor(enemies[j].p.x/42),floor(enemies[j].p.y/42))
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(j)
 var route_budget=2
 for i in range(enemies.size()-1,-1,-1):
  var e=enemies[i]
  e.flash=maxf(0,e.flash-dt);e.attack=maxf(0,e.attack-dt);e.muzzle=maxf(0,e.muzzle-dt);e.fire_cd-=dt
  e.dash_left=maxf(0,e.get("dash_left",0.0)-dt)
  e.anim_clock+=dt;e.hit_pose=maxf(0,e.hit_pose-dt);e.recover=maxf(0,e.recover-dt)
  var delta=player-e.p
  var dir=delta.normalized()
  var speed=e.speed
  if e.get("species","ship")=="octopus":speed*=.70+.60*pow(maxf(0,sin(e.anim_clock*4)),2)
  e.route_cd-=dt
  if e.route_cd<=0 and route_budget>0:
   route_budget-=1
   e.route_cd=.75+fmod(e.phase,.3);e.sight=clear_water_line(e.p,player,26 if e.boss else 16)
   if not e.sight:e.route=navigation.get_point_path(navigation_cell(e.p),navigation_cell(player),true)
   else:e.route=PackedVector2Array()
  if not e.sight and e.route.size()>0:
   while e.route.size()>0 and e.p.distance_to(e.route[0])<24:e.route.remove_at(0)
   if e.route.size()>0:dir=(e.route[0]-e.p).normalized()
  elif delta.length()<135 and e.kind%3!=0 and not e.boss:dir=dir.rotated(1.3);speed*=.75
  if e.get("species","ship")=="jellyfish":
   speed*=.5+.8*pow(maxf(0,sin(e.anim_clock*2.8)),3)
   if e.sight:dir=dir.rotated(sin(e.anim_clock*1.3)*.35)
  elif e.get("species","ship")=="crab" and e.sight:
   dir=delta.normalized().rotated(sin(e.anim_clock*2)*.75);speed*=1.05
  e.heading=rotate_toward(e.heading,dir.angle(),dt*1.5)
  if e.windup>0:
   e.windup=maxf(0,e.windup-dt)
   speed*=.20
   if e.windup<=0:
    enemy_volley(e);e.recover=.42;e.fire_cd=maxf(2.0,3.8-elapsed/180) if not e.boss else 2.3
  elif e.fire_cd<=0 and delta.length()<(175 if e.get("species","ship")=="crab" else 285) and e.sight and e.hit_pose<=0 and e.recover<=0:
   e.windup=.65 if not e.boss else .9
   e.attack_dir=(player+velocity*.35-e.p).normalized()
  if e.recover>0:speed*=.45
  if e.hit_pose>0:speed*=.35
  if e.boss:
   e.charge-=dt
   if e.charge< -4:e.charge=1.35;e.charge_v=dir;sfx("boss")
   if e.charge>.5:speed=0
   elif e.charge>0:dir=e.charge_v;speed=255
  if e.get("dash_left",0.0)>0:dir=e.attack_dir;speed=220
  var cell=Vector2i(floor(e.p.x/42),floor(e.p.y/42))
  for y in range(-1,2):
   for x in range(-1,2):
    for j in buckets.get(cell+Vector2i(x,y),[]):
     if j==i:continue
     var separation:Vector2=e.p-enemies[j].p
     var distance_sq=separation.length_squared()
     if distance_sq>0 and distance_sq<1764:
      var distance=sqrt(distance_sq)
      dir+=separation/distance*(42-distance)*.075
  var vel=dir.normalized()*speed*dt+e.knock*dt
  e.knock=e.knock.move_toward(Vector2.ZERO,dt*420)
  var np=move_body(e.p,vel,14 if not e.boss else 26)
  if np.distance_to(e.p)<.05:
   var tangent=dir.rotated(PI*.5 if sin(e.phase)>0 else -PI*.5)
   np=move_body(e.p,tangent*speed*dt,14)
  e.p=np
  if delta.length()<(29 if not e.boss else 46) and e.attack<=0 and dodge_left<=0:
   hurt((12+minf(12,elapsed/30)) if not e.boss else 28);e.attack=.9

func auto_attack():
 if state!="play":return
 var best:Dictionary={}
 var distance=130.0 if weapon==1 else 170.0
 for e in enemies:
  var delta:Vector2=e.p-player
  var screen_position:Vector2=e.p-cam+Vector2(320,180)
  if not Rect2(36,48,568,250).has_point(screen_position):continue
  if delta.length()>=distance or not clear_water_line(player,e.p,3):continue
  if weapon==1:
   var side=heading+(PI/2 if Vector2.from_angle(heading).cross(delta)>=0 else -PI/2)
   if absf(angle_difference(side,delta.angle()))>.48:continue
  distance=delta.length();best=e
 if best.is_empty():return
 aim=(best.p-player).normalized()
 shoot()

func shoot():
 if shot_cd>0:return
 shot_cd=CADENCE[weapon]*(.65 if skill_buff>0 and class_id==4 else 1.0)
 muzzle=.11 if weapon==3 else .075;shake=maxf(shake,1.5 if weapon!=1 else 3.4)
 var count=7 if weapon==1 else 1
 var firing=cannon_bearing()
 shot_direction=firing
 for n in range(count):
  var angle=firing.angle()+rng.randf_range(-.22,.22) if weapon==1 else firing.angle()+rng.randf_range(-.025,.025)
  var dir=Vector2.from_angle(angle)
  bullets.append({"p":player+dir*27,"v":dir*(390 if weapon!=3 else 460),"life":.38 if weapon==1 else (.44 if weapon==3 else .50),"dmg":DAMAGE[weapon]*damage_boost,"pierce":weapon==3,"left":4 if weapon==3 else 1,"visited":[],"gun":weapon})
 sfx(["shot","shotgun","smg","heavy_shot"][weapon])
 add_combat_fx(player+firing*31,weapon,"muzzle")
 velocity-=firing*(8 if weapon!=3 else 20)
 for i in range(6):
  particles.append({"p":player+firing*29,"v":firing*rng.randf_range(12,30)+Vector2.from_angle(rng.randf()*TAU)*7,"life":.55,"max":.55,"color":Color("bec1a8"),"size":Vector2.ONE*rng.randf_range(2,5)})

func enemy_volley(e:Dictionary):
 var direction=e.get("attack_dir",(player+velocity*.35-e.p).normalized())
 if e.get("windup",0.0)>0:direction=e.attack_dir
 if e.get("species","ship")=="crab":
  e.dash_left=.48;e.recover=.7;e.muzzle=0
  if e.p.distance_to(player)<260:sfx("crab_attack")
  return
 var jelly=e.get("species","ship")=="jellyfish"
 var ink=e.get("species","ship")=="octopus"
 var count=5 if e.boss else (3 if jelly else 1)
 e.muzzle=.18;e.recover=.42
 e.knock-=direction*(20 if e.boss else 36)
 for j in range(count):
  var dir=direction.rotated((j-(count-1)*.5)*.14)
  bullets.append({"p":e.p+dir*(45 if e.boss else 24),"v":dir*(82 if jelly else (112 if ink else (132 if e.boss else 148))),"life":2.8,"dmg":10.0 if jelly else 14.0 if ink else (18.0 if not e.boss else 28.0),"hostile":true,"ink":ink,"electric":jelly})
 if e.p.distance_to(player)<260:sfx("jelly_attack" if jelly else ("ink" if ink else "enemy_shot"))

func update_bullets(dt:float):
 for i in range(bullets.size()-1,-1,-1):
  var b=bullets[i];var old:Vector2=b.p
  b.p+=b.v*dt;b.life-=dt
  if solid(b.p,0):b.life=0;sparks(b.p,Color("a5d4cb"),4)
  if b.life>0:
   if b.get("hostile",false):
    var closest=Geometry2D.get_closest_point_to_segment(player,old,b.p)
    if closest.distance_to(player)<17:hurt(b.dmg);b.life=0;sparks(b.p,Color("d3b389"),5)
   else:
    var hits:Array=[]
    for e in enemies:
     if e in b.get("visited",[]):continue
     var closest=Geometry2D.get_closest_point_to_segment(e.p,old,b.p)
     if closest.distance_to(e.p)<(29 if e.boss else 16):hits.append(e)
    hits.sort_custom(func(a,c):return old.distance_squared_to(a.p)<old.distance_squared_to(c.p))
    for e in hits:
     var j=enemies.find(e)
     if j<0:continue
     add_combat_fx(e.p,int(b.get("gun",2)),"impact")
     sfx("heavy_hit" if b.get("gun",2)==3 else "cannon_hit")
     damage_enemy(j,b.dmg,b.v.normalized()*(125 if b.get("pierce",false) else 48))
     if not b.get("pierce",false):b.life=0;break
     b.visited.append(e);b.left-=1
     upgrades.add_path(old,e.p,"pierce",4-b.left)
     if b.left<=0:b.life=0;break
  if b.life<=0:bullets.remove_at(i)

func damage_enemy(index:int,amount:float,knock=Vector2.ZERO):
 if index>=enemies.size():return
 var e=enemies[index]
 if float(e.get("steam_until",0))>upgrades.phase:amount*=1.25
 e.hp-=amount;e.flash=.12;e.knock+=knock*(1+int(upgrades.ranks.get("impact",0))*.25);e.hit_pose=.30;total_damage+=amount
 if e.windup>0:e.windup=0;e.fire_cd=maxf(e.fire_cd,.75)
 e.dash_left=0
 enemy_sound(e,"down" if e.hp<=0 else "hit")
 sparks(e.p,Color("b5c7ae") if e.get("species","ship")!="ship" else Color("c9a36b"),6)
 if rng.randf()<.45:floating(e.p-Vector2(0,22),str(int(amount)),CREAM)
 if e.hp<=0:
  var p:Vector2=e.p
  kills+=1
  drop_pickup(p+Vector2(0,-7),"xp",3 if not e.boss else 45)
  corpses.append({"p":p,"kind":e.kind,"angle":e.heading,"age":0.0,"species":e.get("species","ship"),"boss":e.boss,"scale":1.65 if e.boss else (.72 if e.kind%3==0 else .84)})
  if corpses.size()>65:corpses.pop_front()
  if rng.randf()<.12:drop_pickup(p+Vector2(9,4),"health",20)
  if rng.randf()<.08:drop_pickup(p+Vector2(9,-7),"armor",25)
  if clear_drop_allowed(rng.randf()):pickups.append({"p":p+Vector2(-10,0),"type":"clear","value":1})
  if e.boss:boss_alive=false;sfx("boss")
  enemies.remove_at(index)

func drop_pickup(p:Vector2,kind:String,value:int):
 for pickup in pickups:
  if pickup.type==kind and pickup.p.distance_squared_to(p)<576:
   pickup.value+=value
   return
 pickups.append({"p":p,"type":kind,"value":value})

func hurt(damage:float):
 if invulnerable>0:return
 invulnerable=.55;hitflash=.15;shake=5;sfx("hurt")
 var blocked=minf(armor,damage*.75);armor-=blocked;hp-=damage-blocked
 if hp<=0:hp=0;state="dead";sfx("boss")

func dodge():
 if dodge_cd>0:return
 dodge_left=.65;dodge_cd=2.5;invulnerable=.5;sfx("dash")
 # Full sail briefly accelerates the hull; the wake follows its actual path.

func skill():
 if skill_cd>0:return
 skill_cd=18;sfx("skill")
 match class_id:
  0:armor=minf(100,armor+65);invulnerable=3;notify("OAK BULWARK / BRACE FOR IMPACT")
  1:hp=minf(max_hp,hp+60);notify("SHIPWRIGHT / EMERGENCY REPAIRS")
  2:turrets.append({"p":player+Vector2(18,0),"life":12.0,"cd":0.0});notify("FLOATING BATTERY DEPLOYED")
  3:skill_buff=7;invulnerable=1;notify("FULL SAIL / CATCH THE WIND")
  4:skill_buff=7;notify("ALL GUN CREWS / FIRE AT WILL")
  5:explode(player,155,190);notify("GREEK FIRE")

func release_firework():
 # Pickup activates immediately; no inventory, key or cooldown can consume it silently.
 if clearing:return
 clearing=true
 var screen=Rect2(cam-Vector2(320,180),Vector2(640,360))
 for i in range(enemies.size()-1,-1,-1):
  if screen.has_point(enemies[i].p):
   var damage=enemies[i].max*.3 if enemies[i].boss else enemies[i].hp+1
   damage_enemy(i,damage)
 bullets=bullets.filter(func(b):return not b.get("hostile",false))
 clearing=false;shake=6;sfx("explosion");add_combat_fx(player,1,"clear")
 notify("SALVAGED FIREWORK / SEA CLEARED")

func explode(p:Vector2,radius:float,damage:float):
 shake=8;sfx("explosion")
 for i in range(enemies.size()-1,-1,-1):
  if enemies[i].p.distance_to(p)<radius:damage_enemy(i,damage,(enemies[i].p-p).normalized()*250)
 for i in range(65):
  var a=rng.randf()*TAU
  particles.append({"p":p,"v":Vector2.from_angle(a)*rng.randf_range(30,200),"life":rng.randf_range(.2,.7),"max":.7,"color":[GOLD,Color("de7d3f"),Color("a14330"),Color("424044")][i%4],"size":Vector2.ONE*rng.randf_range(2,7)})

func update_effects(dt:float):
 for fx in combat_fx:fx.age+=dt
 combat_fx=combat_fx.filter(func(fx):return fx.age<fx.duration)
 for wreck in corpses:wreck.age+=dt
 corpses=corpses.filter(func(w):return w.age<12)
 for i in range(particles.size()-1,-1,-1):
  var p=particles[i];p.p+=p.v*dt;p.v*=.95;p.life-=dt
  if p.life<=0:particles.remove_at(i)
 for i in range(floats.size()-1,-1,-1):
  floats[i].p.y-=dt*15;floats[i].life-=dt
  if floats[i].life<=0:floats.remove_at(i)

func sparks(p:Vector2,c:Color,n:int):
 for i in range(n):particles.append({"p":p,"v":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(12,70),"life":.24,"max":.24,"color":c,"size":Vector2(2,2)})
func floating(p:Vector2,t:String,c:Color):floats.append({"p":p,"t":t,"color":c,"life":.65})
func notify(t:String):message=t;message_left=3.2

func victory():
 state="victory";unlocked=maxi(unlocked,mini(2,map_id+1))
 var save=ConfigFile.new();save.set_value("progress","maps",unlocked);save.save("user://corsair-voyage.cfg");sfx("wave")

func make_audio():
 for n in range(12):
  var voice=AudioStreamPlayer.new();add_child(voice);voice.volume_db=-7;voices.append(voice)
 for type in ["level_up","shot","shotgun","smg","dash","hurt","pickup","wave","ui","empty","skill","explosion","boss","ink","combo_steam","combo_chain","combo_shards","shell_launch","shell_hit","bubble_burst","heavy_shot","heavy_hit","cannon_hit","shell","xp_pick","coin_pick","health_pick","jelly_attack","crab_attack","enemy_shot","ship_hit","octopus_hit","jellyfish_hit","crab_hit","ship_down","octopus_down","jellyfish_down","crab_down"]:
  var rate=22050;var length=.12
  if type in ["shot","shotgun"]:length=.3
  if type in ["wave","skill","boss"]:length=.55
  if type=="level_up":length=.7
  if type=="explosion":length=.7
  if type.begins_with("combo_"):length=.5
  if type in ["heavy_shot","shell"]:length=.45
  if type in ["coin_pick","health_pick","heavy_hit"]:length=.25
  if type.ends_with("_down"):length=.55
  if type.ends_with("_hit"):length=.18
  if type in ["ink","jelly_attack","crab_attack","enemy_shot"]:length=.28
  var data=PackedByteArray();data.resize(int(rate*length)*2)
  var phase=0.0
  var filtered=0.0
  for i in range(int(rate*length)):
   var t=float(i)/rate;var envelope=pow(maxf(0,1-t/length),2);var sample=0.0
   match type:
    "level_up":
     var notes=[523.25,659.25,783.99,1046.5]
     for n in range(4):
      var age=t-n*.095
      if age>=0:sample+=(sin(age*TAU*notes[n])*.30+sin(age*TAU*notes[n]*2)*.06)*exp(-age*7)*minf(1,age/.008)
    "shot","smg","shotgun","heavy_shot":
     var base={"shot":140.0,"shotgun":190.0,"smg":370.0,"heavy_shot":85.0}[type]
     phase+=(base*(1-t/length)+40)/rate
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.4 if type=="shotgun" else .15)
     var noise=.95 if type=="shotgun" else .35
     var decay=42 if type=="smg" else (9 if type=="heavy_shot" else 17)
     sample=(filtered*noise+sin(phase*TAU)*.6+sin(phase*TAU*2.7)*.2)*exp(-t*decay)
     if type=="shotgun":sample+=filtered*.35*exp(-absf(t-.045)*100)
    "shell_launch","shell_hit","bubble_burst":
     phase+=(600-400*t/length)/rate
     sample=(sin(phase*TAU)*.6+sin(phase*TAU*2.5)*.18)*envelope
     if type=="bubble_burst":sample*=.6+.4*cos(t*80)
    "shell":
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.7)
     phase+=(1200-950*t/length)/rate
     sample=(filtered*.38+sin(phase*TAU)*.28)*(0.4+0.6*pow(maxf(0,cos(t*90)),8))*envelope
    "cannon_hit","heavy_hit":
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.3)
     sample=(filtered*.45+sin(t*TAU*(70 if type=="heavy_hit" else 240))*.5)*envelope
    "xp_pick","coin_pick","health_pick":
     var base={"xp_pick":1100.0,"coin_pick":1600.0,"health_pick":660.0}[type]
     var freq=base*(1.25 if t>length*.4 else 1.0)
     phase+=freq/rate
     sample=(sin(phase*TAU)*.55+sin(phase*TAU*2.01)*.16)*envelope
    "combo_steam":
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.16)
     phase+=(320-220*t/length)/rate
     sample=(filtered*.8+sin(phase*TAU)*.3)*sin(PI*t/length)*envelope
    "combo_chain":
     var beat=fmod(t,.14)
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.25)
     sample=(sin(beat*TAU*100)*.5+filtered*.45)*exp(-beat*26)*envelope
    "combo_shards":
     phase+=(900+int(t/.09)%3*260)/rate
     sample=(sin(phase*TAU)*.4+sin(phase*TAU*2.02)*.2)*exp(-fmod(t,.09)*32)*envelope
    "explosion","boss":sample=(rng.randf_range(-1,1)*.5+sin(t*TAU*45)*.5)*envelope
    "hurt":sample=(sin(t*TAU*95)*.65+rng.randf_range(-.3,.3))*envelope
    "dash":sample=(sin(t*TAU*93)+sin(t*TAU*142)*.25)*envelope*.22
    "ink":
     phase+=(220-140*t/length)/rate
     sample=sin(phase*TAU)*envelope*.65
    "enemy_shot":
     phase+=(160-100*t/length)/rate
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.2)
     sample=(sin(phase*TAU)*.6+filtered*.5)*envelope
    "jelly_attack":
     phase+=(640+220*sin(t*25))/rate
     sample=(sin(phase*TAU)+sin(phase*TAU*1.5)*.25)*envelope*.5
    "crab_attack":
     sample=(sin(t*TAU*340)*.5+sin(t*TAU*680)*.2)*exp(-fmod(t,.085)*70)*envelope
    "ship_hit","crab_hit":
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.35)
     sample=(sin(t*TAU*(220 if type=="ship_hit" else 480))*.45+filtered*.4)*envelope
    "octopus_hit","jellyfish_hit":
     phase+=(450-280*t/length+(160 if type=="jellyfish_hit" else 0))/rate
     sample=sin(phase*TAU)*envelope*.65
    "ship_down":
     filtered=lerpf(filtered,sound_rng.randf_range(-1,1),.1)
     sample=(filtered*.8+sin(t*TAU*75)*.35)*envelope
    "octopus_down","jellyfish_down","crab_down":
     var base=380 if type=="octopus_down" else (820 if type=="jellyfish_down" else 560)
     phase+=(base*(1-t/length)+90+sin(t*42)*60)/rate
     sample=(sin(phase*TAU)+sin(phase*TAU*2)*.18)*envelope*.55*(.65+.35*cos(t*45))
    "empty":sample=sin(t*TAU*180)*exp(-t*100)
    "pickup","ui":sample=sin(t*TAU*(900 if t<.045 else 1200))*.25*envelope
    _:sample=sin(t*TAU*([330,440,660][mini(2,int(t*6))]))*.35*envelope
   sample*=minf(1.0,t/.003)
   data.encode_s16(i*2,int(clampf(sample,-1,1)*22000))
  var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data;sounds[type]=stream
 water_player=AudioStreamPlayer.new();add_child(water_player)
 var water:AudioStreamWAV=load("res://assets/audio/sailing-water.wav")
 water=water.duplicate();water.loop_mode=AudioStreamWAV.LOOP_FORWARD
 water.loop_begin=0;water.loop_end=int(water.get_length()*water.mix_rate)
 water_player.stream=water;water_player.volume_db=-80

func update_water_audio(dt:float):
 if not water_player:return
 var target=minf(1,velocity.length()/95)*.075 if state in ["play","intermission","extract"] and not muted and not test_mode else 0.0
 water_gain=move_toward(water_gain,target,dt*.32)
 water_player.volume_db=linear_to_db(maxf(.0001,water_gain))
 if water_gain>.002 and not water_player.playing:water_player.play()
 if water_gain<=.002 and water_player.playing:water_player.stop()

func sfx(type:String,pitch:float=1.0):
 if muted or test_mode or not sounds.has(type):return
 var now=Time.get_ticks_msec()
 var gap=90 if type.ends_with("_hit") or type.ends_with("_down") else (65 if type.ends_with("_pick") else 45)
 if now-int(sound_last.get(type,-1000))<gap:return
 sound_last[type]=now
 var v=voices[audio_index%voices.size()]
 for candidate in voices:
  if not candidate.playing:v=candidate;break
 audio_index+=1
 v.stream=sounds[type]
 v.volume_db=-4 if type=="level_up" else -7 if type in ["shot","shotgun","smg","heavy_shot"] else (-11 if type.ends_with("_hit") else -10)
 v.pitch_scale=pitch*sound_rng.randf_range(.96,1.04);v.play()

func collect_feedback(kind:String,value:int):
 var cue={"xp":"xp_pick","armor":"health_pick","health":"health_pick","clear":"wave"}.get(kind,"pickup")
 sfx(cue)
 add_combat_fx(player,-1,"collect")
 if kind!="xp":floating(player-Vector2(0,35),"+ARMOR" if kind=="armor" else "+REPAIR" if kind=="health" else "FIREWORK!" if kind=="clear" else "+SALVAGE",Color("a6f5e0"))

func enemy_sound(e:Dictionary,event:String):
 if e.p.distance_to(player)<260:sfx(e.get("species","ship")+"_"+event)

# Pixel geometry and text are drawn in a fixed 640 x 360 viewport.
func smooth_polygon(points:PackedVector2Array,color:Color):
 draw_colored_polygon(points,color)
 var edge=points.duplicate();edge.append(points[0])
 if not crisp_ship:draw_polyline(edge,color,.7,true)

func rect(r:Rect2,c:Color):draw_rect(r,c)
func line(a:Vector2,b:Vector2,c:Color,w:float=1):draw_line(a,b,c,w,not crisp_ship)
func pixel_size(size:int)->int:
 return maxi(8,size)
func text(t:String,p:Vector2,size:int=10,c:Color=TEXT):
 size=pixel_size(size)
 for bounds in ui_panel_bounds:
  if bounds.has_point(p):
   c=Color("3d4c47") if c==TEXT or c==CREAM else Color("526d62")
   break
 draw_string(font,p+Vector2(1,1),t,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(.12,.24,.27,.10))
 draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)
func center(t:String,p:Vector2,size:int=10,c:Color=TEXT):text(t,p-Vector2(font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_size(size)).x*.5,0),size,c)
func round_box(r:Rect2,fill:Color,border:Color,width:int=1,radius:int=6):
 var key=fill.to_html()+border.to_html()+str(width)+str(radius)
 if not ui_styles.has(key):
  var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
  style.set_border_width_all(width);style.set_corner_radius_all(radius);style.anti_aliasing=true
  ui_styles[key]=style
 draw_style_box(ui_styles[key],r)

func panel(r:Rect2,border:Color=Color("356c68"),fill:Color=Color("a5c6ac")):
 var warm=fill.r>fill.g*1.14
 ui_panel_bounds.append(r)
 fill=Color("f2c17e") if warm else Color("fff0ce")
 border=Color("ba9471") if warm else Color("ba9471")
 round_box(Rect2(r.position+Vector2(0,2),r.size),Color(.03,.18,.22,.32),Color(.03,.18,.22,.32),0)
 material_box(Rect2(r.position+Vector2(0,1),r.size),fill.darkened(.18),border,0,7)
 round_box(r,fill,border,0,7)
 line(r.position+Vector2(8,3),r.position+Vector2(r.size.x-8,3),Color(1,1,1,.38),1.2)
 line(r.position+Vector2(7,2),r.position+Vector2(r.size.x-8,2),Color(.60,.76,.72,.13))

func button(id:String,label:String,r:Rect2,selected=false,enabled=true):
 var hover=r.has_point(cursor) and enabled
 var fill=Color("e4a057") if selected or hover else Color("72b59f")
 if not enabled:fill=Color("a4b1a1")
 panel(r,Color("a66c50") if selected or hover else Color("3d7e70"),fill)
 center(label,r.position+r.size*.5+Vector2(0,3),8,TEXT if enabled else Color("94a9a4"))
 if enabled:buttons.append({"id":id,"rect":r})

func bar(p:Vector2,size:Vector2,value:float,c:Color):
 round_box(Rect2(p-Vector2.ONE,size+Vector2(2,2)),Color("839cab"),Color("839cab"),0,2)
 if value>0:round_box(Rect2(p,Vector2(size.x*clampf(value,0,1),size.y)),c,c,0,2)

func _draw():
 var perf_start=Time.get_ticks_usec()
 if tier_gallery:draw_tier_gallery();return
 if bake_creature!="":
  for i in range(128):
   var p=Vector2(40+(i%16)*80,40+(i/16)*80)
   var base_species=bake_creature.trim_suffix("_hit").trim_suffix("_down")
   var pose={"anim_clock":i*TAU/128.0,"kind":4 if base_species=="octopus_coral" else 2,"species":base_species}
   if bake_creature.ends_with("_hit"):pose.hit_pose=.15
   if bake_creature.ends_with("_down"):
    draw_wreck({"p":p,"age":i*3.0/127,"kind":pose.kind,"species":"octopus" if base_species.begins_with("octopus") else base_species},Vector2.ZERO)
   elif bake_creature=="ship":draw_ship(p,i*TAU/128,0,.84,true,false,false,Vector2.ZERO,{"bake":true})
   elif bake_creature.begins_with("octopus"):draw_octopus(p,pose,Vector2.ZERO)
   else:draw_sea_creature(p,pose,Vector2.ZERO)
  return
 if not map_texture:return
 buttons.clear()
 ui_panel_bounds.clear()
 var menu_bg=state in ["menu","select"]
 var view=Vector2(630,1000) if menu_bg else cam
 render_offset=Vector2(320,180)-view
 if shake>0 and not menu_bg:render_offset+=Vector2(sin(clock*83),cos(clock*71))*shake*.6
 draw_set_transform(render_offset)
 terrain_canvas.position=render_offset
 draw_island_details()
 draw_ocean(view)
 draw_gulls(view)
 # Sinking hulls settle into the water; loose planks remain briefly afloat.
 for w in corpses:
  if abs(w.p.x-view.x)<380 and abs(w.p.y-view.y)<260:draw_wreck(w,render_offset)
 draw_set_transform(render_offset)
 draw_player_wake()
 if not menu_bg:upgrades.draw_zones(self)
 if not menu_bg:upgrades.world(self)
 if not menu_bg and weapon==1:
  for side in [-1,1]:draw_arc(player,65,heading+side*PI/2-.55,heading+side*PI/2+.55,12,Color(GOLD,.24),1)
 for p in pickups:
  if abs(p.p.x-view.x)>340 or abs(p.p.y-view.y)>220:continue
  var pos:Vector2=p.p+Vector2(0,sin(clock*2+p.p.x)*1.3)
  ellipse(pos+Vector2(1,3),Vector2(5,2),Color(0,.1,.13,.3))
  if p.type=="clear":
   upgrades.icon(self,"flare",pos,.38);draw_arc(pos,13,clock,clock+5,24,GOLD,1.3,true);continue
  if p.type=="xp":
   material_ellipse(pos,Vector2(3,4),Color("79f0dc"));continue
  rect(Rect2(pos-Vector2(4,3),Vector2(8,7)),Color("493b2e"));rect(Rect2(pos-Vector2(3,2),Vector2(6,5)),Color("a68451"))
  if p.type=="armor":material_ellipse(pos,Vector2(3,4),Color("8cc8e5"))
  elif p.type=="health":line(pos-Vector2(2,0),pos+Vector2(2,0),MINT,2);line(pos-Vector2(0,2),pos+Vector2(0,2),MINT)
  else:rect(Rect2(pos-Vector2(1,2),Vector2(2,4)),Color("2e4147"))
 var objects:Array=[]
 for p in props:
  if not menu_bg and abs(p.p.x-view.x)<360 and abs(p.p.y-view.y)<270:objects.append(p)
 for e in enemies:
  if abs(e.p.x-view.x)<400 and abs(e.p.y-view.y)<260:objects.append({"p":e.p,"type":"enemy","data":e})
 if not menu_bg:objects.append({"p":player,"type":"player"})
 objects.sort_custom(func(a,b):return a.p.y<b.p.y)
 for o in objects:
  match o.type:
   "player":
    draw_ship(player,heading,class_id,1.0,false,invulnerable>0 and fmod(clock,.15)<.04,false,render_offset,{"equipment":true})
    if muzzle>0:
     var p=player+shot_direction*28
     smooth_polygon(PackedVector2Array([p-shot_direction.orthogonal()*3,p+shot_direction*14,p+shot_direction.orthogonal()*4]),GOLD)
     draw_circle(p+shot_direction*3,3,CREAM)
   "enemy":
    var e:Dictionary=o.data
    if draw_cached_creature(e):pass
    elif e.get("species","ship")=="octopus":draw_octopus(e.p,e,render_offset)
    elif e.get("species","ship") in ["jellyfish","crab"]:draw_sea_creature(e.p,e,render_offset)
    else:draw_ship(e.p,e.heading,e.kind%6,1.65 if e.boss else (.72 if e.kind%3==0 else .84),true,e.flash>0,e.boss,render_offset,e)
    if e.windup>0:
     var a:Vector2=e.attack_dir
     var readiness=1-e.windup/(.9 if e.boss else .65)
     line(e.p+a*27,e.p+a*(38+readiness*18),Color(.90,.61,.35,.35+readiness*.4),1.2)
     draw_circle(e.p+a*25,2+readiness*2,Color(.94,.70,.38,.5))
    if e.muzzle>0 and e.get("species","ship")=="ship":
     var a:Vector2=e.attack_dir
     var tip=e.p+a*(45 if e.boss else 24)
     star(tip,4+e.muzzle*25,Color("e9bd77"))
     for n in range(3):
      var smoke=tip+a*(.18-e.muzzle)*70+Vector2(n*2,-n*3)
      ellipse(smoke,Vector2(3+n,2+n),Color(.70,.73,.65,e.muzzle*.8))
    if e.boss and e.charge>.5:
     var a:Vector2=e.charge_v
     line(e.p+a*48,e.p+a*100,Color("c98764"),1)
     smooth_polygon(PackedVector2Array([e.p+a*104,e.p+a*95+a.orthogonal()*5,e.p+a*95-a.orthogonal()*5]),Color("c98764"))
    if e.hp<e.max:bar(e.p+Vector2(-15,-33 if not e.boss else -52),Vector2(30,2),e.hp/e.max,Color("c17659"))
   _:draw_prop(o)
 for t in turrets:
  draw_set_transform(render_offset+t.p,sin(clock*.6)*.03)
  for j in range(-2,3):rect(Rect2(-10,j*4,21,3),Color("936e43"))
  rect(Rect2(-3,-4,7,8),Color("344b4d"));line(Vector2.ZERO,(nearest_enemy(t.p)-t.p).normalized()*12,Color("a7b7ac"),3)
  draw_set_transform(render_offset)
 for b in bullets:
  if b.get("electric",false):
   material_ellipse(b.p,Vector2(4,4),Color("a7b4c1"))
   draw_arc(b.p,5,clock*3,clock*3+4.5,16,Color("d5c99b"),.8,true)
   continue
  if b.get("ink",false):
   for j in range(3):ellipse(b.p-b.v.normalized()*j*3,Vector2(3.5-j*.6,3-j*.5),Color(.28,.24,.36,.8-j*.15))
   continue
  if b.has("gun"):
   draw_cannon_round(b);continue
  var hostile=b.get("hostile",false)
  var c=Color("ef9f9b") if hostile else Color("ffe6a8")
  line(b.p-b.v.normalized()*7,b.p,c.darkened(.3),1)
  draw_circle(b.p,2 if hostile else 1.5,Color("74859a"));rect(Rect2(b.p-Vector2.ONE,Vector2.ONE),c)
 for p in particles:rect(Rect2(p.p,p.size),Color(p.color,clampf(p.life/p.max,0,1)*(.6 if p.color==Color("bec1a8") else 1)))
 upgrades.draw_bursts(self)
 draw_combat_fx()
 for f in floats:text(f.t,f.p,9,f.color)
 if not menu_bg and state=="extract":
  var target=Vector2(1280,260);var v=(target-player).normalized();var marker=player+v*78
  text("BEACON %dM"%int(player.distance_to(target)/5),marker-Vector2(26,12),8,GOLD)
  smooth_polygon(PackedVector2Array([marker+v*8,marker+v.rotated(2.4)*7,marker+v.rotated(-2.4)*7]),GOLD)
 draw_set_transform(Vector2.ZERO)
 for i in range(4):draw_rect(Rect2(i*3,i*3,640-i*6,360-i*6),Color(.73,.94,.89,.012*(4-i)),false,3)
 if menu_bg:
  rect(Rect2(0,0,640,360),Color(.03,.17,.24,.08 if state=="menu" else .16))
  draw_menu()
 else:
  draw_hud()
  upgrades.hud(self)
  if hitflash>0:rect(Rect2(0,0,640,360),Color(.6,.2,.12,hitflash*.6))
  if state=="upgrade":upgrades.cards(self)
  elif state=="pause":draw_pause()
  elif state in ["dead","victory"]:draw_result()

 perf_draw_us+=Time.get_ticks_usec()-perf_start;perf_draw_count+=1

func draw_ocean(view:Vector2):
 var stroke_index=0
 for w in sea_strokes:
  stroke_index+=1
  if abs(w.p.x-view.x)>340 or abs(w.p.y-view.y)>200:continue
  var phase=clock*.7+w.phase
  var alpha=.035+maxf(0,sin(phase))*.085
  var p:Vector2=w.p+Vector2(sin(phase)*2,cos(phase*.7))
  line(p,p+Vector2(w.width*.45,-1),Color(.50,.89,.91,alpha))
  line(p+Vector2(w.width*.45,-1),p+Vector2(w.width,0),Color(.50,.89,.91,alpha*.75))
  if stroke_index%9==0:
   var current=PackedVector2Array()
   for k in range(13):current.append(p+Vector2(k*2-12,sin(k*.20+phase)*2.1))
   draw_polyline(current,Color(.22,.72,.79,.07+sin(phase)*.025),1.3,true)
  # A few sunlit facets breathe independently, never a full-screen white wash.
  if stroke_index%11==0:
   var glint=pow(maxf(0,sin(clock*.85+w.phase)),7)
   if glint>.03:
    line(p-Vector2(3,0),p+Vector2(6,0),Color(.76,.94,.96,glint*.48),1.1)
    line(p+Vector2(1,-1.6),p+Vector2(1,1.6),Color(.87,.97,.94,glint*.36),.7)
    line(p+Vector2(3,3),p+Vector2(8,3),Color(.67,.91,.94,glint*.18),.7)


func draw_gulls(view:Vector2):
 for i in range(5):
  var p=Vector2(472+i*99,842+(i%3)*92)+Vector2(sin(clock*.16+i)*18,cos(clock*.22+i)*8)
  if abs(p.x-view.x)>340 or abs(p.y-view.y)>195:continue
  ellipse(p+Vector2(3,12),Vector2(6,2),Color(.23,.59,.67,.08))
  var flap=sin(clock*3+i)*1.8
  line(p-Vector2(6,2+flap),p,Color("d1dfcf"),2)
  line(p,p+Vector2(6,-2-flap),Color("d1dfcf"),2)

func draw_player_wake():
 for i in range(1,wake_history.size()):
  var a=wake_history[i-1];var b=wake_history[i]
  if a.p.distance_to(b.p)>18:continue
  var width_a=6+a.age*7;var width_b=6+b.age*7
  var strength=(1-a.age/2.5)*a.strength
  for side in [-1,1]:
   line(a.p+a.dir.orthogonal()*width_a*side,b.p+b.dir.orthogonal()*width_b*side,Color(.72,.88,.81,strength*.45),1)
  if a.age<.7:line(a.p,b.p,Color(.7,.86,.8,strength*.19),2)

func ellipse(p:Vector2,r:Vector2,c:Color):
 draw_soft_shape(p,r,c,0)

# All rounded bodies, eyes and soft shadows share one texture, allowing the
# compatibility renderer to batch them instead of submitting separate meshes.
func draw_soft_shape(p:Vector2,r:Vector2,c:Color,kind:int):
 if legacy_render:
  draw_mesh(ellipse_mesh(kind==1,kind==2),null,Transform2D(0,r,0,p),c)
  return
 if crisp_ship and kind!=2:
  if title_shape_atlas==null:build_title_shape_atlas()
  var extent=r*1.01
  draw_texture_rect_region(title_shape_atlas,Rect2(p-extent,extent*2),Rect2(kind*512,0,512,512),c)
  return
 if shape_atlas==null:build_shape_atlas()
 if r.x<=0 or r.y<=0:return
 var extent=r*1.06
 draw_texture_rect_region(shape_atlas,Rect2(p-extent,extent*2),Rect2(kind*128,0,128,128),c)

func build_title_shape_atlas():
 var img=Image.create(1024,512,false,Image.FORMAT_RGBA8)
 for y in range(512):
  for x in range(512):
   var uv=(Vector2(x+.5,y+.5)/256.0-Vector2.ONE)*1.01
   var radius=uv.length()
   var edge=clampf((1.004-radius)/.004,0,1)
   img.set_pixel(x,y,Color(1,1,1,edge))
   var tone=clampf(.88+uv.normalized().dot(Vector2(-.6,-.8))*.14,.65,1)
   var shade=Color.WHITE.lerp(Color(tone*.96,tone,minf(1,tone*1.07)),minf(1,radius))
   shade.a=edge;img.set_pixel(x+512,y,shade)
 title_shape_atlas=ImageTexture.create_from_image(img)

func build_shape_atlas():
 var img=Image.create(384,128,false,Image.FORMAT_RGBA8)
 for y in range(128):
  for x in range(128):
   var uv=(Vector2(x+.5,y+.5)/64.0-Vector2.ONE)*1.06
   var radius=uv.length()
   var edge=clampf((1.035-radius)/.035,0,1)
   img.set_pixel(x,y,Color(1,1,1,edge))
   var tone=clampf(.88+uv.normalized().dot(Vector2(-.6,-.8))*.14,.65,1)
   var shade=Color.WHITE.lerp(Color(tone*.96,tone,minf(1,tone*1.07)),minf(1,radius))
   shade.a=edge;img.set_pixel(x+128,y,shade)
   img.set_pixel(x+256,y,Color(1,1,1,pow(maxf(0,1-radius),1.7)*.22))
 shape_atlas=ImageTexture.create_from_image(img)

func ellipse_mesh(shaded:bool,shadow:bool=false)->ArrayMesh:
 var key=int(shaded)+int(shadow)*2
 if ellipse_meshes.has(key):return ellipse_meshes[key]
 var verts=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
 var segments=32
 verts.append(Vector3.ZERO);colors.append(Color(1,1,1,1 if not shadow else .22))
 var rings=8 if shadow else 2
 for ring in range(rings):
  var radius=(ring+1.0)/rings if shadow else (1.0 if ring==0 else 1.035)
  for i in range(segments):
   var u=Vector2.from_angle(i*TAU/segments)
   verts.append(Vector3(u.x*radius,u.y*radius,0))
   var a=pow(1-radius,1.7)*.22 if shadow else (1.0 if ring==0 else 0.0)
   var tone=1.0
   if shaded:tone=clampf(.88+u.dot(Vector2(-.6,-.8))*.14,.65,1)
   colors.append(Color(tone*.96,tone, minf(1.0,tone*1.07),a) if shaded else Color(tone,tone,tone,a))
 for i in range(segments):indices.append_array(PackedInt32Array([0,1+i,1+(i+1)%segments]))
 for ring in range(rings-1):
  for i in range(segments):
   var a=1+ring*segments+i;var b=1+ring*segments+(i+1)%segments
   indices.append_array(PackedInt32Array([a,a+segments,b,b,a+segments,b+segments]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 ellipse_meshes[key]=mesh
 return mesh

func material_polygon(points:PackedVector2Array,base:Color,strength:float=.16,light:Vector2=Vector2(-.6,-.8)):
 var bounds=Rect2(points[0],Vector2.ZERO)
 for v in points:bounds=bounds.expand(v)
 var colors=PackedColorArray()
 for v in points:
  var uv=(v-bounds.get_center())/Vector2(maxf(bounds.size.x*.5,1),maxf(bounds.size.y*.5,1))
  var shade=uv.dot(light)*strength
  colors.append(base.lerp(Color("fff2d1"),shade) if shade>0 else base.lerp(Color("587d80"),-shade))
 draw_polygon(points,colors)
 var edge=points.duplicate();edge.append(points[0])
 draw_polyline(edge,Color(base,.55 if crisp_ship else .25),.22 if crisp_ship else .6,not crisp_ship)

# The same warm upper-left light and cool lower-right shade as the hull and sails.
func material_ellipse(p:Vector2,r:Vector2,c:Color):
 draw_soft_shape(p,r,c,1 if c.a>=.99 else 0)

func material_box(r:Rect2,c:Color,_border:Color,_width:int=1,radius:int=5):
 var points=PackedVector2Array()
 var rr=minf(radius,minf(r.size.x,r.size.y)*.5)
 for corner in range(4):
  var center=r.position+Vector2(rr if corner in [0,3] else r.size.x-rr,rr if corner<2 else r.size.y-rr)
  for j in range(9):points.append(center+Vector2.from_angle(PI+corner*PI*.5+j*PI/16)*rr)
 material_polygon(points,c,.24)

func soft_shadow(p:Vector2,r:Vector2,alpha:float):
 draw_soft_shape(p,r*1.32,Color(.05,.20,.22,alpha/.22),2)

func curved_shape(points:Array)->PackedVector2Array:
 var curve=Curve2D.new()
 for node in points:curve.add_point(node[0],node[1],node[2])
 return curve.tessellate(5,2.0)

func draw_ship(p:Vector2,angle:float,job:int,scale_factor:float,enemy:bool,flash:bool,boss:bool,offset:Vector2,pose:Dictionary={}):
 var previous_crisp=crisp_ship
 crisp_ship=true
 var rocking=sin(clock*1.8+p.x*.05)*.018
 var stretch=Vector2.ONE
 var lift=Vector2.ZERO
 if not pose.is_empty():
  var t:float=pose.get("anim_clock",clock)
  rocking+=sin(t*3.3)*.035
  lift.y=sin(t*3.3)*1.3
  var hit:float=pose.get("hit_pose",0.0)/.30
  var recoil:float=pose.get("recover",0.0)/.42
  var charge:float=pose.get("windup",0.0)
  if charge>0:
   var tension=1-charge/(.9 if boss else .65)
   rocking-=tension*.07;stretch=Vector2(1-tension*.035,1+tension*.045)
  if recoil>0:
   lift-=pose.get("attack_dir",Vector2.RIGHT)*sin(recoil*PI)*3
   rocking+=sin(recoil*PI*2)*.09
  if hit>0:
   rocking+=sin(hit*PI*3)*hit*.13
   stretch=Vector2(1-.07*sin(hit*PI),1+.08*sin(hit*PI))
  var sinking:float=pose.get("sink",0.0)
  if sinking>0:
   rocking+=sinking*.75;stretch*=Vector2(1-sinking*.18,1-sinking*.65)
   lift.y+=sinking*8
 if pose.get("bake",false):rocking=0;lift=Vector2.ZERO
 draw_set_transform(offset+p+lift,rocking,stretch*scale_factor)
 var paint=Art.HULLS[job] if not enemy else Color("b67b9f")
 var cloth=Art.SAILS[job] if not enemy else Color("d8cddd")
 if flash:paint=paint.lightened(.25)
 soft_shadow(Vector2(2,7),Vector2(26,12),.23)
 # Project the water-plane hull, keeping height vertical on screen as the boat turns.
 var rim=PackedVector2Array()
 for i in range(40):
  var a=i*TAU/40
  var local=Vector2(cos(a)*(28 if cos(a)>0 else 23),sin(a)*17)
  var rotated=local.rotated(angle)
  rim.append(Vector2(rotated.x,rotated.y*.62-5))
 var belly=PackedVector2Array()
 for v in rim:belly.append(Vector2(v.x*.87,v.y*.88+10))
 material_polygon(belly,paint.darkened(.27),.25)
 var side=PackedVector2Array()
 for v in rim:side.append(v+Vector2(0,5))
 material_polygon(side,paint,.28)
 material_polygon(rim,cloth.darkened(.12),.14)
 var deck=PackedVector2Array()
 for v in rim:deck.append(Vector2(v.x*.86,(v.y+5)*.79-5))
 material_polygon(deck,Color("e5bc87"),.17)
 if title_detail:
  # Crisp seams are vector strokes and remain sharp when the window grows.
  var rail=rim.duplicate();rail.append(rim[0])
  draw_polyline(rail,Color("b58c6c"),.32,not crisp_ship)
  var front=PackedVector2Array()
  for v in rim:
   if v.y>-4:front.append(v+Vector2(0,4.4))
  if front.size()>1:draw_polyline(front,paint.darkened(.17),.30,not crisp_ship)
  for y in [-7,-4,-1]:line(Vector2(-10,y),Vector2(9,y),Color(.60,.43,.29,.30),.20)
 # Big rounded portholes show the visible toy side without cluttering the deck.
 for x in [-11,0,11]:
  material_ellipse(Vector2(x,8),Vector2(2.8,2.4),Color("ffd16b"))
  ellipse(Vector2(x,8),Vector2(1.6,1.4),paint.darkened(.38))
 var forward=Vector2(cos(angle),sin(angle)*.62)
 line(forward*22-Vector2(0,5),forward*32-Vector2(0,5),paint.darkened(.18),2.3)
 if pose.get("equipment",false):upgrades.draw_mounts(self,angle,false)
 var mast=Vector2(-2,-7)
 line(mast,mast+Vector2(0,-35),Color("967451"),2.4)
 # A broad raised pillow sail reads upright, not as a top-down map icon.
 var billow=0.0 if pose.get("bake",false) else sin(clock*1.7+p.x*.03)*.7+pose.get("recover",0.0)*2
 var sail=curved_shape([[Vector2(-2,-40),Vector2.ZERO,Vector2(10,-2)],[Vector2(18+billow,-31),Vector2(0,-6),Vector2(1,9)],[Vector2(14,-12),Vector2(7,-2),Vector2(-9,2)],[Vector2(-3,-15),Vector2(5,2),Vector2(2,-8)],[Vector2(-2,-40),Vector2(2,9),Vector2.ZERO]])
 material_polygon(sail,cloth,.31)
 draw_arc(Vector2(5,-28),10,-1.9,-.6,16,Color(.97,.97,.94,.35),1.2,not crisp_ship)
 var jib=curved_shape([[Vector2(-5,-38),Vector2.ZERO,Vector2(-9,6)],[Vector2(-20,-16),Vector2(2,-7),Vector2(5,2)],[Vector2(-6,-15),Vector2(-5,1),Vector2(1,-10)],[Vector2(-5,-38),Vector2(-1,8),Vector2.ZERO]])
 material_polygon(jib,cloth.darkened(.06),.24)
 line(Vector2(-5,-38),Vector2(-20,-16),Color(.55,.51,.44,.35),.7)
 # Small embroidered face stays upright and legible.
 for x in [4,11]:
  if pose.get("hit_pose",0.0)>0 or pose.get("sink",0.0)>0:
   line(Vector2(x-1,-24),Vector2(x+1,-22),Color("60545d"),.9)
   line(Vector2(x-1,-22),Vector2(x+1,-24),Color("60545d"),.9)
  else:ellipse(Vector2(x,-24),Vector2(1.1,1.6),Color("60545d"))
 draw_arc(Vector2(7.5,-23),2.4,.3,PI-.3,32,Color("84616a"),.8,not crisp_ship)
 var flutter=0.0 if pose.get("bake",false) else sin(clock*3+p.x)*1.2
 smooth_polygon(PackedVector2Array([Vector2(-2,-43),Vector2(9,-42+flutter),Vector2(7,-37+flutter),Vector2(-2,-38)]),paint)
 if boss:star(Vector2(7,-30),4,paint)
 if not enemy:
  var gun_root=-forward*12+Vector2(0,-3)
  var gun_dir=cannon_bearing()
  material_ellipse(gun_root,Vector2(4,3),Color("526c77"))
  line(gun_root,gun_root+gun_dir*7,Color("526c77"),3.3)
  line(gun_root-Vector2(0,.6),gun_root+gun_dir*6-Vector2(0,.6),Color("99b2b6"),.8)
 if pose.get("equipment",false):upgrades.draw_mounts(self,angle,true)
 var contact=PackedVector2Array([Vector2(-18,13),Vector2(-5,15),Vector2(8,15),Vector2(19,12)])
 draw_polyline(contact,Color(.67,.89,.92,.28),.8,not crisp_ship)
 draw_set_transform(offset)
 crisp_ship=previous_crisp


func draw_octopus(p:Vector2,pose:Dictionary,offset:Vector2):
 var t:float=pose.get("anim_clock",clock)
 var hit:float=pose.get("hit_pose",0.0)/.30
 var charge:float=pose.get("windup",0.0)
 var recoil:float=pose.get("recover",0.0)/.42
 var sink:float=pose.get("sink",0.0)
 var puff=(1-charge/.65)*.16 if charge>0 else 0.0
 var pulse=sin(t*4)
 var scale=Vector2(1+puff+hit*.12-recoil*.12,1+puff-hit*.15+recoil*.1)*(1-sink*.8)
 soft_shadow(p+Vector2(3,6),Vector2(18,8)*(1-sink*.7),.18)
 draw_set_transform(offset+p+Vector2(sin(hit*17)*hit*2,pulse*1.3+sink*7),sink*1.8,scale*1.12)
 var skin=Color("ec9e94") if int(pose.get("kind",2))%4==0 else Color("e591a2")
 if pose.get("flash",0.0)>0:skin=skin.lightened(.18)
 # Eight short, curling arms paddle in alternating pairs.
 for i in range(8):
  var x=-16+i*4.6
  var wave=sin(t*4+i*.8)*(3 if charge<=0 else 1)
  var root=Vector2(x*.7,3)
  var tip=Vector2(x+sin(t*3+i)*2,13+wave-hit*6)
  var arm=PackedVector2Array()
  for j in range(13):
   var u=j/12.0
   arm.append(root.lerp(tip,u)+Vector2(sin(u*PI)*sin(i+1)*4,sin(u*PI)*2))
  draw_polyline(arm,skin.darkened(.24),5.5,true)
  draw_polyline(arm,skin,4.0,true)
  material_ellipse(tip,Vector2(2.3,2.6),skin)
  ellipse(tip-Vector2(0,1),Vector2(.9,.8),Color("f7c8b6"))
 material_ellipse(Vector2(0,-4),Vector2(17,17),skin)
 material_ellipse(Vector2(-5,-13),Vector2(5,2),skin.lightened(.25))
 for side in [-1,1]:
  var eye=Vector2(side*5.2,-3)
  if hit>0 or sink>0:
   line(eye-Vector2(2,1),eye+Vector2(1,0),Color("24335c"),1.1)
   line(eye+Vector2(1,0),eye-Vector2(2,-1),Color("24335c"),1.1)
  else:
   ellipse(eye,Vector2(2.1,2.8),Color("24335c"))
   draw_circle(eye-Vector2(.4,.6),.55,Color("f4fbff"))
  ellipse(eye+Vector2(side*3,4),Vector2(2.6,1.2),Color("f1beb3"))
 if charge>0 or recoil>0:
  material_ellipse(Vector2(0,4),Vector2(2.8+puff*6,2.5),skin.darkened(.22))
  ellipse(Vector2(0,4),Vector2(1.5,1.3),Color("24335c"))
 else:draw_arc(Vector2(0,1),3.2,.35,PI-.35,16,Color("65426d"),.8,true)
 draw_set_transform(offset)

func draw_sea_creature(p:Vector2,pose:Dictionary,offset:Vector2):
 var jelly=pose.get("species","")=="jellyfish"
 var t:float=pose.get("anim_clock",clock)
 var sink:float=pose.get("sink",0.0)
 var hit:float=pose.get("hit_pose",0.0)/.3
 var charge:float=pose.get("windup",0.0)
 var ready=1-charge/.65 if charge>0 else 0.0
 var pulse=sin(t*(3.0 if jelly else 6))
 soft_shadow(p+Vector2(3,7),Vector2(17,7)*(1-sink*.8),.16)
 var stretch=Vector2(1+.08*pulse,1-.10*pulse) if jelly else Vector2(1,1)
 stretch*=1-sink*.7
 if hit>0:stretch*=Vector2(1+.12*hit,1-.12*hit)
 draw_set_transform(offset+p+Vector2(0,pulse*(2 if jelly else .6)+sink*7),sink*(.2 if jelly else PI),stretch*1.12)
 var body=Color("b4a0d0") if jelly else Color("e9a264")
 if pose.get("flash",0.0)>0:body=body.lightened(.16)
 if jelly:
  # A contracting bell tows soft ribbons, each with a delayed wave.
  for i in range(6):
   var ribbon=PackedVector2Array()
   for j in range(14):ribbon.append(Vector2(-12+i*4.8+sin(t*2-j*.35+i)*2,j*1.5+2))
   draw_polyline(ribbon,body.darkened(.18),2.4,true)
   draw_polyline(ribbon,body.lightened(.10),1,true)
  material_ellipse(Vector2(0,-6),Vector2(17+ready*2,14-ready*3),body)
  for i in range(5):material_ellipse(Vector2(-12+i*6,3),Vector2(4.5,3.5),body)
  material_ellipse(Vector2(-5,-13),Vector2(5,2.3),Color("d2b9eb"))
  if charge>0:draw_arc(Vector2(0,-5),20+ready*3,-PI,0,30,Color(.89,.77,.49,.3+ready*.5),1.3,true)
 else:
  # Jointed legs scuttle sideways while raised claws telegraph the lunge.
  for side in [-1,1]:
   for i in range(3):
    var knee=Vector2(side*(17+i),3+i*4+sin(t*6+i)*2)
    var toe=Vector2(side*(23+i),7+i*4+sin(t*6+i)*3)
    line(Vector2(side*10,3),knee,body.darkened(.2),2.6);line(knee,toe,body,2.2)
   var claw=Vector2(side*(21-ready*3),-8-ready*10)
   line(Vector2(side*12,0),claw,body.darkened(.2),3)
   material_ellipse(claw,Vector2(7.5,8),body)
   var gap=2+ready*3 if pose.get("dash_left",0.0)<=0 else 1.0
   line(claw+Vector2(0,-6),claw+Vector2(side*gap,-1),Color("65426d"),1.2)
  material_ellipse(Vector2(0,0),Vector2(17,12),body)
  material_ellipse(Vector2(-5,-6),Vector2(6,2),body.lightened(.26))
  for side in [-1,1]:line(Vector2(side*6,-5),Vector2(side*7,-12),body.darkened(.2),2)
 for side in [-1,1]:
  var eye=Vector2(side*6,-5 if jelly else -12)
  if hit>0 or sink>0:
   line(eye-Vector2(1.5,1),eye+Vector2(1.5,1),Color("24335c"),1)
   line(eye-Vector2(1.5,-1),eye+Vector2(1.5,-1),Color("24335c"),1)
  else:
   ellipse(eye,Vector2(2.1,2.7),Color("24335c"));draw_circle(eye-Vector2(.4,.5),.5,Color("f4fbff"))
  ellipse(Vector2(side*10,0),Vector2(2.2,1),Color("ffb3be"))
 draw_arc(Vector2(0,-2),3,.3,PI-.3,14,Color("65426d"),.8,true)
 draw_set_transform(offset)

func draw_wreck(w:Dictionary,offset:Vector2):
 var age:float=w.age
 var species:String=w.get("species","ship")
 if species!="ship" and bake_creature=="":
  if age>=3:return
  var key=("octopus_coral" if species=="octopus" and int(w.kind)%4==0 else species)+"_down"
  if creature_atlases.has(key):
   var frame=mini(127,int(age/3.0*128))
   draw_texture_rect_region(creature_atlases[key],Rect2(w.p-Vector2(40,40),Vector2(80,80)),Rect2((frame%16)*160,(frame/16)*160,160,160))
   return
 if age>=10:return
 if w.get("species","ship") in ["jellyfish","crab"]:
  if age<2:draw_sea_creature(w.p,{"species":w.species,"sink":age/2,"anim_clock":age*4,"hit_pose":maxf(0,.3-age)},offset)
  if age>.45 and age<2.6:
   for i in range(5):
    var p=w.p+Vector2(sin(i*5)*16,-age*8+i*2)
    if w.species=="jellyfish":star(p,2,Color(.78,.75,.65,(1-age/2.6)*.65))
    else:draw_arc(p,2,0,TAU,12,Color(.72,.80,.67,(1-age/2.6)*.6),.8,true)
  return
 if w.get("species","ship")=="octopus":
  if age<1.8:draw_octopus(w.p,{"kind":w.kind,"sink":clampf(age/1.8,0,1),"hit_pose":maxf(0,.3-age),"anim_clock":age*2},offset)
  if age>.35 and age<3:
   for j in range(6):
    var bubble=w.p+Vector2(sin(j*4)*13,-(age-.35)*10+j*2)
    draw_arc(bubble,1.2+fmod(j*.7+age,2),0,TAU,16,Color(.72,.80,.67,(1-age/3)*.65),.9,true)
  return
 var size:float=w.get("scale",.84)
 # Impact, list and collapse, then scattered floating timber; no sprite popping.
 if age<1.65:
  var sinking=clampf((age-.2)/1.45,0,1)
  draw_ship(w.p,w.angle,w.kind%6,size*(1-sinking*.35),true,age<.10,w.get("boss",false),offset,{"sink":sinking,"hit_pose":maxf(0,.25-age),"anim_clock":age})
  draw_set_transform(offset)
  if age<.28:
   for i in range(5):
    var a=i*TAU/5
    var p=w.p+Vector2.from_angle(a)*(8+age*65)*size
    line(p,p+Vector2.from_angle(a)*5,Color("d9b57a"),1.2)
 if age>.55:
  var spread=minf(1,(age-.55)/1.7)
  var fade=clampf((10-age)/6,0,1)
  for i in range(5):
   var a=w.angle+i*2.39
   var p=w.p+Vector2.from_angle(a)*(7+spread*(9+i*2))*size
   draw_set_transform(offset+p,a+sin(age+i)*.12)
   line(Vector2(-3,0),Vector2(3,0),Color(Color("b6925e"),fade*.8),2.6)
  draw_set_transform(offset)
  if age<3:
   for i in range(4):
    var p=w.p+Vector2(sin(i*9)*14,-(age-.55)*5+i*3)
    draw_arc(p,1.3+fmod(age+i*.3,1.0),0,TAU,12,Color(.65,.79,.72,(1-age/3)*.5),.7,true)
 draw_set_transform(offset)

func draw_island_details():
 var view=Vector2(630,1000) if state in ["menu","select"] else cam
 # Cull fine surface details before submitting geometry.
 for idx in range(land_polygons.size()):
  var pts:PackedVector2Array=land_polygons[idx]
  var middle=Vector2.ZERO
  for v in pts:middle+=v
  middle/=pts.size()
  if middle.distance_to(view)>650:continue
  for k in range(55):
   var a=k*2.399+idx
   var radius=sqrt(fmod(k*.618+.17,1.0))
   var edge=pts[(k*17+idx)%pts.size()]
   var pos=middle.lerp(edge,radius*.72)
   if absf(pos.x-view.x)>340 or absf(pos.y-view.y)>200:continue
   ellipse(pos,Vector2(2.5+(k%3),1.1),Color(.66,.73,.36,.085))
  for k in range(20):
   var pos=middle.lerp(pts[(k*23+idx)%pts.size()],.86+fmod(k*.037,.10))
   if absf(pos.x-view.x)>340 or absf(pos.y-view.y)>200:continue
   ellipse(pos,Vector2(1.1,.65),Color(.50,.36,.19,.15))
  for k in range(8):
   var edge=pts[(k*11+idx*7)%pts.size()]
   var pos=middle.lerp(edge,.60)+Vector2(sin(clock*1.15+k+idx)*.35,0)
   if absf(pos.x-view.x)>340 or absf(pos.y-view.y)>200:continue
   soft_shadow(pos+Vector2(3,3),Vector2(11,5),.18)
   material_ellipse(pos+Vector2(0,2),Vector2(10,5),Color("679f74"))
   material_ellipse(pos-Vector2(2,1),Vector2(9,6),Color("a0cf7e"))
   if k%2==0:
    for j in range(5):ellipse(pos+Vector2.from_angle(j*TAU/5)*2.3,Vector2(2,2),Color("e6bb49"))
    draw_circle(pos,1.4,Color("d69235"))
  for k in range(3):
   var pos=middle.lerp(pts[(k*29+13)%pts.size()],.9)
   if absf(pos.x-view.x)>340 or absf(pos.y-view.y)>200:continue
   star(pos,3.6,Color("c9784f"))

func heart(p:Vector2,size:float,c:Color):
 draw_circle(p+Vector2(-size*.45,-size*.3),size*.65,c)
 draw_circle(p+Vector2(size*.45,-size*.3),size*.65,c)
 smooth_polygon(PackedVector2Array([p+Vector2(-size,-size*.1),p+Vector2(size,-size*.1),p+Vector2(0,size)]),c)

func star(p:Vector2,size:float,c:Color):
 if size<.8:return
 var points=PackedVector2Array()
 for i in range(10):points.append(p+Vector2.from_angle(i*TAU/10-PI/2)*(size if i%2==0 else size*.47))
 smooth_polygon(points,c)

func gun(p:Vector2,type:int):
 rect(Rect2(p+Vector2(-2,-4),Vector2(7,10)),Color("674e34"))
 rect(Rect2(p+Vector2(0,-3),Vector2(17 if type>0 else 13,6)),Color("142a30"))
 rect(Rect2(p+Vector2(0,-2),Vector2(16 if type>0 else 12,4)),Color("647c77"))
 line(p+Vector2(2,-2),p+Vector2(13,-2),Color("aab5a3"))
 if type==1:line(p+Vector2(13,-4),p+Vector2(13,4),Color("8c9e91"),2)
 if type==3:rect(Rect2(p+Vector2(15,-2),Vector2(6,4)),Color("a58f5c"))

func draw_prop(o:Dictionary):
 var p:Vector2=o.p
 if o.type in ["house","lighthouse","palm","rock"]:
  soft_shadow(p+Vector2(8,7),Vector2(23,9) if o.type in ["house","lighthouse"] else Vector2(14,6),.26)
 match o.type:
  "palm":
   var sd=int(o.seed)
   draw_set_transform(render_offset+p)
   material_ellipse(Vector2(6,3),Vector2(16,6),Color(.31,.56,.44,.13))
   line(Vector2.ZERO,Vector2(-3,-24),Color("ae885f"),5)
   line(Vector2(1,-1),Vector2(-2,-23),Color("e7c48f"),2)
   for y in [-5,-11,-17,-22]:line(Vector2(-2,y),Vector2(1,y+1),Color(.42,.30,.18,.32),.65)
   var top=Vector2(-3,-27)
   for i in range(5):
    var a=i*TAU/5+float(sd%6)*.2
    var tip=top+Vector2.from_angle(a)*Vector2(13,9)
    var mid=top.lerp(tip,.56)+Vector2(sin(clock*1.1+sd*.01+i*.7)*.65,sin(clock*.9+i)*.3)
    material_ellipse(mid,Vector2(10,7),[Color("5f9e71"),Color("91c56b"),Color("b6db7f")][i%3])
    draw_arc(mid+Vector2(1,1),5.0,3.5,4.6,12,Color(.80,.91,.72,.32),.7,true)
   draw_circle(top+Vector2(-2,3),2.5,Color("b79572"))
   draw_circle(top+Vector2(3,3),2,Color("d0b084"))
   draw_set_transform(render_offset)
  "rock":
   material_ellipse(p+Vector2(2,4),Vector2(13,6),Color(.32,.5,.52,.12))
   material_ellipse(p-Vector2(0,3),Vector2(12,12),Color("a8bdc2"))
   material_ellipse(p-Vector2(2,7),Vector2(8,6),Color("b9bca7"))
   material_ellipse(p+Vector2(6,3),Vector2(8,6),Color("b6c9c8"))
  "house":
   material_ellipse(p+Vector2(4,7),Vector2(23,9),Color(.43,.58,.42,.14))
   material_box(Rect2(p-Vector2(17,18),Vector2(34,28)),Color("fff0ce"),Color("d2bc9b"),1,5)
   material_box(Rect2(p-Vector2(11,7),Vector2(9,9)),Color("a5d9db"),Color("83b6bc"),1,3)
   line(p+Vector2(-7,-6),p+Vector2(-7,0),Color("eaf6e5"))
   material_box(Rect2(p+Vector2(6,-5),Vector2(8,15)),Color("bca380"),Color("bca380"),0,3)
   draw_circle(p+Vector2(8,3),1,Color("f7dfad"))
   for y in [-13,-8,3,8]:line(p+Vector2(-14,y),p+Vector2(-3,y),Color(.53,.39,.25,.13),.5)
   material_polygon(PackedVector2Array([p+Vector2(-22,-17),p+Vector2(-15,-25),p+Vector2(-3,-31),p+Vector2(3,-31),p+Vector2(15,-25),p+Vector2(22,-17)]),Color("d77660"))
   material_box(Rect2(p+Vector2(-22,-19),Vector2(44,7)),Color("ed826f"),Color("d77660"),1,3)
   line(p+Vector2(-16,-23),p+Vector2(-4,-29),Color("f5d1b3"),2)
   for x in [-12,-5,2,9]:line(p+Vector2(x,-24),p+Vector2(x+5,-19),Color(.48,.24,.20,.22),.6)
   heart(p+Vector2(0,-18),3,Color("e6c693"))
  "port":
   material_box(Rect2(p+Vector2(-104,-11),Vector2(111,25)),Color("99bab1"),Color("99bab1"),0,4)
   material_box(Rect2(p+Vector2(-103,-14),Vector2(110,24)),Color("d4a576"),Color("cca784"),1,4)
   for i in range(0,104,7):line(p+Vector2(-101+i,-10),p+Vector2(-101+i,7),Color("d6b38e"))
   for x in [-100,-57,-14,3]:
    for y in [-14,8]:
     material_ellipse(p+Vector2(x+1,y+3),Vector2(3,4),Color("b99b7b"))
     material_ellipse(p+Vector2(x+1,y),Vector2(3,2),Color("ffe2b6"))
   material_box(Rect2(p+Vector2(-25,-30),Vector2(20,17)),Color("efc397"),Color("cda381"),1,3)
   line(p+Vector2(-22,-27),p+Vector2(-8,-16),Color("d2a681"))
   heart(p+Vector2(-15,-22),3,Color("fff0cd"))
   line(p+Vector2(-45,-14),p+Vector2(-45,-56),Color("c2a17d"),2)
   material_polygon(PackedVector2Array([p+Vector2(-44,-55),p+Vector2(-20,-51),p+Vector2(-22,-44),p+Vector2(-44,-42)]),Color("ed826f"))
   heart(p+Vector2(-34,-48),3,Color("fff1d8"))
  "buoy":
   var bob=sin(clock*2+p.x)*1.2
   material_ellipse(p+Vector2(0,3),Vector2(7,2),Color(.3,.63,.7,.13))
   material_ellipse(p+Vector2(0,-1+bob),Vector2(5,6),Color("eea8aa"))
   line(p+Vector2(-3,0+bob),p+Vector2(3,0+bob),Color("fff4db"),2)
   material_ellipse(p+Vector2(0,-7+bob),Vector2(2,2),Color("f8d692"))
  "lighthouse":
   material_box(Rect2(p+Vector2(-150,25),Vector2(150,13)),Color("d4a576"),Color("cdb18d"),1,3)
   for x in range(-146,0,7):line(p+Vector2(x,27),p+Vector2(x,35),Color("d8b992"))
   material_ellipse(p+Vector2(5,10),Vector2(28,12),Color(.4,.58,.48,.14))
   material_box(Rect2(p+Vector2(-18,-49),Vector2(36,60)),Color("fff0ce"),Color("d7c7ad"),1,8)
   material_box(Rect2(p+Vector2(-16,-11),Vector2(32,10)),Color("ed826f"),Color("ed826f"),0,3)
   material_box(Rect2(p+Vector2(-16,-35),Vector2(32,10)),Color("ed826f"),Color("ed826f"),0,3)
   material_box(Rect2(p+Vector2(-15,-67),Vector2(30,19)),Color("3e9690"),Color("a4c6bf"),1,5)
   for y in [-45,-29,-18,5]:line(p+Vector2(-13,y),p+Vector2(-4,y),Color(.55,.40,.27,.14),.55)
   for x in [-8,3]:material_box(Rect2(p+Vector2(x,-64),Vector2(5,13)),Color("e8ca89"),Color("e8ca89"),0,2)
   material_polygon(PackedVector2Array([p+Vector2(-20,-66),p+Vector2(-12,-75),p+Vector2(0,-81),p+Vector2(12,-75),p+Vector2(20,-66)]),Color("ed826f"))
   material_box(Rect2(p+Vector2(-7,-3),Vector2(14,15)),Color("a3c6c6"),Color("a3c6c6"),0,6)
   star(p+Vector2(0,-40),4,Color("e3c591"))
   var beam=Vector2.from_angle(clock*.24)*130
   material_polygon(PackedVector2Array([p+Vector2(0,-58),p+Vector2(0,-58)+beam+beam.orthogonal()*.12,p+Vector2(0,-58)+beam-beam.orthogonal()*.12]),Color(1,.97,.77,.1))

func hud_card(r:Rect2):
 # Small enamel-like cards: cool rim, matte face, no wood grain or pegs.
 var face=Color("fff0ce") if r.size.y>30 else Color("fff0ce")
 round_box(Rect2(r.position+Vector2(0,2),r.size),Color(.12,.22,.28,.18),Color(.12,.22,.28,.18),0,9)
 material_box(Rect2(r.position+Vector2(0,1),r.size),face.darkened(.18),face,0,8)
 round_box(r,face,face,0,8)
 line(r.position+Vector2(9,2),r.position+Vector2(r.size.x-9,2),Color(.89,.94,.95,.25),.6)


func hud_text(t:String,p:Vector2,size:int=10,c:Color=TEXT):
 var ink=Color("3d4c47")
 if c==GOLD:ink=Color("7e725b")
 elif c==MINT:ink=Color("597d70")
 draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_size(size),ink)


func draw_hud():
 var shown_state=old_state if state=="pause" else state
 # Three quiet anchors: vessel health, voyage status and a compact chart.
 hud_card(Rect2(12,12,128,38))
 hud_text("HULL",Vector2(21,26),8,MINT)
 hud_text("%d / %d"%[int(hp),int(max_hp)],Vector2(64,26),10)
 bar(Vector2(21,33),Vector2(110,4),hp/max_hp,Color("ed907b"))
 hud_text("ARMOR %d"%int(armor),Vector2(21,46),7,MINT)
 bar(Vector2(80,43),Vector2(51,2),armor/100,Color("6bb8b1"))
 center("%02d:%02d"%[int(elapsed)/60,int(elapsed)%60],Vector2(320,26),11)
 if shown_state=="play":center("%d DEFEATED"%kills,Vector2(320,40),8,MINT)
 var chart=Rect2(564,12,64,64)
 hud_card(Rect2(561,9,70,70))
 draw_texture_rect(mini_texture,chart,false)
 var mp=chart.position+player/1900*64
 draw_circle(mp,2,GOLD);line(mp,mp+Vector2.from_angle(heading)*4,TEXT)
 draw_circle(chart.position+Vector2(475,1015)/1900*64,1.5,MINT)
 for e in enemies:
  if e.boss:draw_circle(chart.position+e.p/1900*64,2,Color("d57962"))
 if shown_state=="extract":draw_circle(chart.position+Vector2(1280,260)/1900*64,2,GOLD)
 if boss_alive:
  for e in enemies:
   if e.boss:bar(Vector2(250,49),Vector2(140,3),e.hp/e.max,Color("ed907b"))
 if music_muted:text("MUSIC OFF",Vector2(12,273),8,MINT)


func draw_menu():
 # One primary action, a compact sea selector, and an uncluttered boat preview.
 text("CORSAIR",Vector2(76,122),43,Color("fff0ce"))
 text("TIDES",Vector2(78,165),38,Color("edac8e"))
 text("A little boat. An endless adventure.",Vector2(80,190),9,Color("d2f5ec"))
 title_detail=true
 draw_ship(Vector2(469,201),-.8,0,2.65,false,false,false,Vector2.ZERO)
 title_detail=false
 button("play","START SAILING",Rect2(78,219,226,36),true)
 var strip=Rect2(78,272,226,25)
 round_box(strip,Color(.10,.31,.30,.48),Color(.10,.31,.30,.48),0,8)
 for i in range(3):
  var r=Rect2(80+i*75,274,72,21)
  var selected=map_id==i
  var hover=r.has_point(cursor)
  if selected or hover:round_box(r,Color("f2c17e") if selected else Color(.56,.78,.69,.35),Color.TRANSPARENT,0,6)
  var label=["EMERALD","STORM","CORAL"][i]
  var color=Color("3d4c47") if selected else Color("e0eee0")
  draw_string(font,r.get_center()+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x*.5,3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,color)
  buttons.append({"id":"map%d"%i,"rect":r})
 center("WASD to sail  /  Auto fire  /  Enter to start",Vector2(320,337),8,Color("c4e1d6"))

func compass(p:Vector2,radius:float,alpha:float=1.0):
 draw_arc(p,radius,0,TAU,48,Color(GOLD,alpha),1)
 for i in range(8):
  var d=Vector2.from_angle(i*TAU/8-PI/2)
  var side=d.orthogonal()
  var length=radius*(.92 if i%2==0 else .57)
  smooth_polygon(PackedVector2Array([p+d*length,p+side*3,p]),Color(GOLD,alpha))
  smooth_polygon(PackedVector2Array([p+d*length,p-side*3,p]),Color(MINT,alpha*.5))



func draw_pause():
 rect(Rect2(0,0,640,360),Color(.12,.25,.29,.60));panel(Rect2(201,95,238,173))
 center("DROP ANCHOR",Vector2(320,126),20,GOLD)
 center("LV %d   /   %d SUNK"%[level,kills],Vector2(320,148),9,MINT)
 center("WASD MOVE / AUTO FIRE",Vector2(320,283),8,TEXT)
 center("1-4 CANNONS / AUTO ABILITIES",Vector2(320,298),8,TEXT)
 button("resume","RESUME  [ESC]",Rect2(225,166,190,30),true)
 button("menu","RETURN TO TITLE",Rect2(225,205,190,28))
 button("music","MUSIC: OFF" if music_muted else "MUSIC: ON",Rect2(225,240,190,22),not music_muted)

func draw_result():
 var won=state=="victory"
 rect(Rect2(0,0,640,360),Color(.12,.25,.29,.60));panel(Rect2(157,58,326,246),GOLD if won else Color("d9a0a0"))
 center("VOYAGE COMPLETE" if won else "LOST AT SEA",Vector2(320,98),25,MINT if won else Color("bd8b94"))
 center("THE SEA KEEPS ITS SECRETS." if not won else "THE LIGHTHOUSE GUIDES YOU HOME.",Vector2(320,120),9,Color("7e9b93"))
 line(Vector2(181,135),Vector2(459,135),Color("b9ccbe"))
 text("OPERATION",Vector2(183,157),10,Color("7c9696"));text(MAP_NAMES[map_id],Vector2(320,157),10)
 text("SUNK / RANK",Vector2(183,179),10,Color("7c9696"));text("%03d / %d"%[kills,level],Vector2(320,179),10,GOLD)
 text("TIME AT SEA",Vector2(183,201),10,Color("7c9696"));text("%02d:%02d"%[int(elapsed)/60,int(elapsed)%60],Vector2(320,201),10)
 if won and map_id<2:button("next","NEXT SEA ROUTE >",Rect2(183,224,274,29),true)
 else:button("retry","SET SAIL AGAIN >",Rect2(183,224,274,29),true)
 button("menu","RETURN TO TITLE",Rect2(183,261,274,25))

func capture_run():
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/title.png")
 state="menu";queue_redraw()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/fleet.png")
 reset_run();weapon=2;owned[2]=true;wave=2;wave_left=5;message="SAILS AHOY! READY THE CREW!"
 for i in range(8):spawn_enemy()
 for i in range(enemies.size()):
  enemies[i].p=player+Vector2.from_angle(i*TAU/enemies.size())*rng.randf_range(115,205)
  if solid(enemies[i].p):enemies[i].p=Vector2(620+rng.randf_range(-70,70),player.y+rng.randf_range(-170,170))
  enemies[i].heading=(player-enemies[i].p).angle()
 for i in range(45):sail(Vector2(.25,-1).normalized(),.035)
 velocity=Vector2.from_angle(heading)*45;cam=player
 await get_tree().create_timer(.05).timeout
 aim=(enemies[0].p-player).normalized();cursor=Vector2(320,180)+aim*110;shot_cd=0;shoot()
 for i in range(2):enemy_volley(enemies[i])
 queue_redraw()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/gameplay.png")
 upgrades.pending=1;upgrades.offer(self);queue_redraw()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/cannon-cards.png")
 # Inspect the other two maps in the actual renderer.
 for m in [1,2]:
  map_id=m;generate_map();state="intermission";cam=player;message_left=0;queue_redraw()
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://captures/map-%d.png"%m)
 map_id=0;generate_map();state="extract";player=Vector2(1280,370);cam=Vector2(1280,290);velocity=Vector2.ZERO;heading=-PI/2
 enemies.clear();bullets.clear();wake_history.clear();message_left=0;queue_redraw()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/lighthouse.png")
 print("CAPTURE PASS: cute title, fleet, battle, upgrades, three seas and lighthouse")
 for v in voices:v.stop()
 water_player.stop()
 await get_tree().create_timer(.18).timeout
 get_tree().quit()

func check(condition:bool,label:String):
 if not condition:
  test_failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)

func enemy_motion_capture():
 reset_run();state="play";wave=1;wave_left=0;message_left=0
 set_process(false)
 player=Vector2(620,1010);cam=player;velocity=Vector2.ZERO;invulnerable=999
 enemies.clear();bullets.clear();corpses.clear();spawn_enemy()
 var actor=enemies[0];actor.p=player+Vector2(100,-55);actor.heading=PI;actor.fire_cd=.5;actor.hp=100;actor.max=100
 var args=OS.get_cmdline_user_args()
 var species="octopus" if "--octopus-capture" in args else ("jellyfish" if "--jellyfish-capture" in args else ("crab" if "--crab-capture" in args else "ship"))
 actor.species=species
 var capture_dir="res://captures/"+species+"-motion"
 DirAccess.make_dir_recursive_absolute(capture_dir)
 for frame in range(150):
  var dt=1.0/30
  clock+=dt
  if species=="crab" and frame>=35 and frame<65:player=move_body(player,Vector2(0,1.8))
  if frame==65 and not enemies.is_empty():damage_enemy(0,12,Vector2(35,-12))
  if frame==85 and not enemies.is_empty():damage_enemy(0,999,Vector2(60,-15))
  update_enemies(dt);update_bullets(dt);update_effects(dt)
  queue_redraw();await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_dir+"/frame-%03d.png"%frame)
 print("ENEMY MOTION CAPTURE PASS: move, windup, shot, recoil, hit, sinking")
 get_tree().quit()

func self_test():
 # Hold an eligible target for a full minute per cannon: no magazine pauses.
 for gun in range(4):
  reset_run();weapon=gun;owned[gun]=true;heading=-PI/2
  enemies.clear();spawn_enemy();enemies[0].p=player+Vector2(90,0)
  var volleys=0;var last_frame=-1;var longest_gap=0
  for frame in range(3600):
   shot_cd=maxf(0,shot_cd-1.0/60);auto_attack()
   if not bullets.is_empty():
    if volleys==0:check(bullets.size()==(7 if gun==1 else 1),"continuous volley pellet count")
    volleys+=1
    if last_frame>=0:longest_gap=maxi(longest_gap,frame-last_frame)
    last_frame=frame
   bullets.clear();particles.clear();combat_fx.clear()
  check(volleys>=int(60.0/(CADENCE[gun]+1.0/60))-1,"cannon %d sustains a minute of automatic fire"%gun)
  check(longest_gap<=ceili(CADENCE[gun]*60)+1,"cannon %d has no reload gaps"%gun)
 reset_run();heading=-PI/2;sail(Vector2.RIGHT,.1)
 check(velocity.x>0 and absf(velocity.y)<.01,"movement follows requested direction immediately")
 reset_run();enemies.clear();spawn_enemy();enemies[0].p=player+Vector2(230,0);auto_attack()
 check(bullets.is_empty(),"auto fire waits until enemy is nearby")
 enemies[0].p=player+Vector2(100,0);auto_attack()
 check(bullets.size()==1 and bullets[0].life<=.5,"nearby enemy receives short range shot")
 reset_run();state="play";enemies.clear();bullets.clear();spawn_enemy()
 enemies[0].p=player+Vector2(100,0);shot_cd=0
 auto_attack()
 check(bullets.size()==1,"automatic fire without mouse input")
 bullets.clear();enemies.clear();shot_cd=0;auto_attack()
 check(bullets.is_empty(),"automatic fire waits without targets")
 reset_run();state="intermission";spawn_enemy();enemies[0].p=player+Vector2(100,0);auto_attack()
 check(bullets.is_empty(),"automatic fire stops outside battle")
 for species in ["jellyfish","crab"]:
  reset_run();enemies.clear();bullets.clear();spawn_enemy()
  var creature=enemies[0];creature.species=species;creature.p=player+Vector2(120,0);creature.fire_cd=0
  update_enemies(.01);check(creature.windup>0,"%s anticipates attack"%species)
  update_enemies(.7)
  check((bullets.size()==3 and bullets[0].get("electric",false)) if species=="jellyfish" else (bullets.is_empty() and creature.dash_left>0),"%s distinct attack release"%species)
  damage_enemy(0,1);check(creature.dash_left==0 and creature.hit_pose>0,"%s hit reaction interrupts lunge"%species)
  damage_enemy(0,999);check(corpses.size()==1 and corpses[0].species==species,"%s distinct defeat"%species)
 reset_run();enemies.clear();bullets.clear();spawn_enemy()
 var squid=enemies[0];squid.species="octopus";squid.p=player+Vector2(100,0);squid.fire_cd=0
 update_enemies(.01);check(squid.windup>0 and bullets.is_empty(),"octopus visibly winds up")
 update_enemies(.7);check(bullets.size()==1 and bullets[0].get("ink",false),"octopus emits damaging ink projectile")
 damage_enemy(0,999)
 check(corpses.size()==1 and corpses[0].species=="octopus","octopus defeat retains creature identity")
 reset_run()
 reset_run();enemies.clear();bullets.clear();spawn_enemy()
 var actor=enemies[0];actor.species="ship";actor.p=player+Vector2(100,0);actor.fire_cd=0
 update_enemies(.01)
 check(actor.windup>0 and bullets.is_empty(),"enemy anticipates before projectile")
 update_enemies(.2)
 check(bullets.is_empty(),"no early projectile during windup")
 damage_enemy(0,1)
 check(actor.windup==0 and actor.hit_pose>0,"hit interrupts windup with reaction")
 actor.hit_pose=0;actor.fire_cd=0;update_enemies(.01);update_enemies(.7)
 check(bullets.size()==1 and actor.recover>0,"one shot at release with recovery")
 var old_kills=kills;damage_enemy(0,999)
 check(enemies.is_empty() and corpses.size()==1 and kills==old_kills+1,"death rewards once and leaves animated wreck")
 update_effects(2)
 check(corpses.size()==1 and corpses[0].age>=2,"wreck persists beyond sinking phase")
 reset_run()
 var enter=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true
 state="menu";_unhandled_input(enter)
 check(state=="play" and class_id==0,"Enter starts basic boat directly")
 state="menu";action("map1");check(state=="menu" and map_id==1,"title map selector preserves menu")
 action("play");check(state=="play" and map_id==1,"start uses selected map")
 map_id=0;generate_map()
 buttons=[{"id":"play","rect":Rect2(0,0,30,30)}]
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(10,10)
 _unhandled_input(click);check(state=="play","mouse buttons use viewport coordinates")
 reset_run()
 check(not solid(player),"berth is navigable")
 check(solid(Vector2(170,1000)),"islands block the hull")
 var before=player;player=move_body(player,Vector2(25,0));check(player.x>before.x,"helm movement path")
 var old_heading=heading
 sail(Vector2.RIGHT,.1)
 check(absf(angle_difference(old_heading,heading))<.9,"helm turns gradually")
 check(velocity.length()>0 and velocity.length()<50,"sailing accelerates with inertia")
 var old_speed=velocity.length();sail(Vector2.ZERO,.02)
 check(velocity.length()>0 and velocity.length()<old_speed,"hull coasts and decelerates")
 player=Vector2(620,1010);velocity=Vector2.ZERO
 check(wake_history.size()>0,"moving stern records continuous wake")
 player=Vector2(620,1010)
 state="play";check(spawn_clock>0,"continuous spawn timer initialized")
 spawn_enemy();var e=enemies[0];e.p=player+Vector2(70,0);e.hp=10;aim=Vector2.RIGHT
 shoot()
 for i in range(20):update_bullets(.01)
 check(kills==1,"bullet segment collision and enemy kill")
 check(pickups.size()>0,"sunk vessel leaves salvage")
 upgrades.pending=1;upgrades.choices=["swivel"];state="upgrade";upgrades.choose(self,0)
 check(owned[2] and weapon==2,"level card unlocks and equips cannon")
 dodge();check(dodge_left>0 and invulnerable>0,"dodge invulnerability")
 invulnerable=0;hp=100;armor=100;hurt(20);check(hp==95 and armor==85,"armor damage absorption")
 invulnerable=0;var old_hull=hp
 bullets.clear();bullets.append({"p":player+Vector2(35,0),"v":Vector2(-200,0),"life":1.0,"dmg":20.0,"hostile":true})
 update_bullets(.15)
 check(hp<old_hull,"enemy cannonball damages the hull")
 bullets.clear();var saved_weapon=weapon;var saved_heading=heading
 weapon=1;heading=0;aim=Vector2.RIGHT;shot_cd=0
 check(absf(cannon_bearing().dot(Vector2.RIGHT))<.6,"grapeshot stays within a flank firing arc")
 shoot();check(bullets.size()==7,"broadside emits seven pellets")
 bullets.clear();weapon=saved_weapon;heading=saved_heading
 var was_test=test_mode;test_mode=false;velocity=Vector2(80,0);water_gain=0
 update_water_audio(.2);check(water_player.playing and water_gain>0,"water loop follows real hull speed")
 velocity=Vector2.ZERO;update_water_audio(1)
 check(not water_player.playing and water_gain==0,"water loop fades to silence at rest")
 test_mode=was_test
 for k in range(6):
  class_id=k;skill_cd=0;hp=40;armor=0;skill()
  check(skill_cd>0,"class skill %d"%k)
 enemies.clear();spawn_enemy(true);check(enemies[0].boss and enemies[0].hp>=1700,"flagship boss")
 var boss_index=enemies.size()-1;damage_enemy(boss_index,10000);check(not boss_alive,"boss can be defeated")
 enemies.clear();state="play";spawn_clock=0;update_game(.01);check(state=="play" and enemies.size()==1,"empty sea automatically spawns enemy")
 enemies.clear();elapsed=300;spawn_clock=0;update_game(.01);check(state=="play" and enemies.size()==1,"continuous mode never transitions to wave clear")
 for m in range(3):
  map_id=m;generate_map();check(obstacles.size()>=8,"map %d geometry"%m)
  check(not solid(Vector2(620,1010)),"map %d safe entry"%m)
  check(not solid(Vector2(1280,260)),"map %d accessible extraction"%m)
  check(navigation.get_point_path(navigation_cell(Vector2(620,1010)),navigation_cell(Vector2(1280,260))).size()>1,"map %d harbor-to-beacon sea route"%m)
 if "--persistence-test" in OS.get_cmdline_user_args():
  var cfg=ConfigFile.new();var had_save=cfg.load("user://corsair-voyage.cfg")==OK
  map_id=0;victory()
  var verify=ConfigFile.new();check(verify.load("user://corsair-voyage.cfg")==OK and verify.get_value("progress","maps",0)>=1,"extraction saves unlocked map")
  if had_save:cfg.save("user://corsair-voyage.cfg")
  else:DirAccess.remove_absolute("user://corsair-voyage.cfg")
 if test_failures==0:print("ALL TESTS PASSED: helm, inertia, wake, hostile cannonballs, broadsides, upgrades, 6 ship abilities, 3 routes, water audio")
 get_tree().quit(0 if test_failures==0 else 1)

func perf_test():
 reset_run();rng.seed=20261105;state="play";wave_left=999;spawn_clock=999;invulnerable=999
 for i in range(32):
  spawn_enemy();enemies[-1].p=player+Vector2.from_angle(i*TAU/32)*130
 for i in range(30):await get_tree().process_frame
 perf_draw_us=0;perf_draw_count=0;perf_update_us=0;perf_update_count=0
 var start=Time.get_ticks_usec()
 for i in range(180):await get_tree().process_frame
 print("PERF frames=",perf_draw_count," fps=",180000000.0/(Time.get_ticks_usec()-start)," draw_ms=",perf_draw_us/1000.0/maxi(1,perf_draw_count)," update_ms=",perf_update_us/1000.0/maxi(1,perf_update_count))
 get_tree().quit()

func fresh_start_capture():
 # Exercise the first node draw and ordinary Enter flow without regenerating the map.
 await get_tree().create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/fresh-title.png")
 var key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
 _unhandled_input(key)
 await get_tree().create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/fresh-gameplay.png")
 cam=Vector2(1280,290);player=Vector2(1280,370)
 await get_tree().process_frame
 cam=Vector2(1280,290);queue_redraw()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/fresh-island.png")
 print("FRESH START PASS: initial menu, Enter launch and island camera without map reload")
 get_tree().quit()

func map_load_test():
 for pass_index in range(2):
  for m in range(3):
   if pass_index==0:
    Art.cached_worlds.erase(m);navigation_cache.erase(m);chart_cache.erase(m)
   var started=Time.get_ticks_usec()
   map_id=m;generate_map()
   print("MAP_LOAD pass=",pass_index," map=",m," ms=",(Time.get_ticks_usec()-started)/1000.0)
   assert(mini_texture.get_width()==88)
 get_tree().quit()

func audio_check():
 set_process(false);muted=false;test_mode=false
 var recorder=AudioEffectRecord.new()
 var slot=AudioServer.get_bus_effect_count(0)
 AudioServer.add_bus_effect(0,recorder)
 recorder.set_recording_active(true)
 reset_run();aim=Vector2.RIGHT
 await get_tree().create_timer(.25).timeout
 for gun_id in range(4):
  weapon=gun_id;shot_cd=0;shoot()
  await get_tree().create_timer(.6).timeout
 for species in ["ship","octopus","jellyfish","crab"]:
  enemies.clear();spawn_enemy()
  var e=enemies[0];e.species=species;e.p=player+Vector2(100,0);e.hp=100;e.attack_dir=Vector2.LEFT
  enemy_volley(e)
  await get_tree().create_timer(.4).timeout
  damage_enemy(0,10)
  await get_tree().create_timer(.35).timeout
  damage_enemy(0,1000)
  await get_tree().create_timer(.7).timeout
 for kind in ["xp","armor","health","clear"]:
  collect_feedback(kind,5)
  await get_tree().create_timer(.4).timeout
 sfx("shell_launch")
 await get_tree().create_timer(.6).timeout
 recorder.set_recording_active(false)
 var recording=recorder.get_recording()
 DirAccess.make_dir_recursive_absolute("res://captures")
 recording.save_to_wav("res://captures/combat-audio.wav")
 AudioServer.remove_bus_effect(0,slot)
 print("AUDIO CHECK PASS: actual player shots and four enemy attack/hit/defeat paths recorded")
 get_tree().quit()

func upgrade_check():
 test_mode=true;reset_run()
 upgrades.gain(self,30);upgrades.offer(self)
 check(state=="upgrade" and upgrades.pending==2,"XP queues two choices")
 var before=elapsed
 _process(.2)
 check(elapsed==before,"upgrade pauses combat")
 upgrades.choices=["bubble","mine","escort"];upgrades.choose(self,0)
 check(state=="upgrade" and upgrades.ranks.bubble==1,"choice applies and queued level opens")
 upgrades.choices=["mine","escort","shell"];upgrades.choose(self,0)
 check(state=="play" and upgrades.ranks.mine==1,"final choice resumes combat")
 upgrades.ranks.escort=1;upgrades.ranks.battery=1;upgrades.ranks.flare=1;upgrades.pending=1;upgrades.offer(self)
 check(not "shell" in upgrades.choices,"six weapon slots include cannon")
 for id in ["bubble","mine","escort","shell","starfish"]:
  reset_run();upgrades.ranks[id]=5;spawn_enemy();enemies[0].p=player+Vector2(40,0);enemies[0].hp=999;enemies[0].max=999
  var health:float=enemies[0].hp
  if id=="mine":
   upgrades.tick(self,.01)
   check(enemies[0].hp==health,"mine waits until enemy enters trigger radius")
   enemies[0].p=upgrades.shots[0].landing
  for i in range(60):upgrades.tick(self,1.0/60);update_bullets(1.0/60)
  check(enemies[0].hp<health,"automatic upgrade deals damage: "+id)
 reset_run();hp=40;upgrades.ranks.repair=1;upgrades.tick(self,.1)
 check(hp==52,"repair crew automatically heals hull")
 upgrades.ranks.battery=1;upgrades.tick(self,.1)
 check(upgrades.zones.is_empty(),"mortar does not fire without target")
 spawn_enemy();enemies[0].p=player+Vector2(40,0);enemies[0].hp=999
 upgrades.ranks.flare=1
 for step in range(15):upgrades.tick(self,.1)
 check(enemies[0].hp<999,"firework card damages nearby enemy")
 upgrades.ranks={"power":1,"blast":1,"magnet":1,"impact":1,"repair":1,"hull":1};upgrades.pending=1;upgrades.offer(self)
 check(upgrades.INFO.size()-upgrades.ARMS.size()-upgrades.CANNONS.size()==6,"six non-shield non-speed abilities")
 reset_run();check(upgrades.ranks.is_empty() and upgrades.shots.is_empty(),"new voyage clears upgrades")
 upgrades.gain(self,12);upgrades.offer(self);upgrades.choices=["bubble","shell","magnet"]
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/upgrades.png")
 print("UPGRADE CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func add_combat_fx(p:Vector2,gun:int,kind:String):
 if combat_fx.size()>=64:combat_fx.pop_front()
 combat_fx.append({"p":p,"gun":gun,"kind":kind,"age":0.0,"duration":.32 if kind=="muzzle" else .45})

func draw_cannon_round(b:Dictionary):
 var gun_id=int(b.gun);var dir=b.v.normalized()
 var c=[Color("ffbd57"),Color("ff9572"),Color("80e8ff"),Color("b6b0ff")][gun_id]
 var length=[13,8,22,48][gun_id]
 line(b.p-dir*length,b.p,Color(c,.24),6 if gun_id==3 else 3)
 line(b.p-dir*length*.7,b.p,c,2)
 if gun_id==3:
  line(b.p-dir*9,b.p+dir*4,Color("455579"),7)
  line(b.p-dir*8-Vector2(0,1.5),b.p+dir*2-Vector2(0,1.5),Color("c8bcff"),2)
  draw_arc(b.p-dir*16,8,dir.angle()-1,dir.angle()+1,10,Color(.8,.73,1,.65),1.5,true)
 else:material_ellipse(b.p,Vector2.ONE*(2.5 if gun_id==0 else 1.6),Color("314f83"))
 ellipse(b.p-Vector2(1,1),Vector2.ONE,Color("effcff"))

func draw_combat_fx():
 for fx in combat_fx:
  var u=fx.age/fx.duration;var fade=1-u;var p:Vector2=fx.p
  var c=Color("93f6da") if fx.gun<0 else [Color("ffc25b"),Color("ff9572"),Color("80e8ff"),Color("b6b0ff")][fx.gun]
  if fx.kind=="clear":
   draw_arc(p,20+u*420,0,TAU,80,Color(1,.8,.4,fade),4,true)
   for i in range(18):star(p+Vector2.from_angle(i*TAU/18)*(20+u*350),5*fade,Color("ffe7a1"))
   continue
  var radius=(8+u*(30 if fx.gun==3 else 19))*(.7 if fx.kind=="collect" else 1)
  draw_arc(p,radius,0,TAU,24,Color(c,fade*.65),1.4,true)
  if fx.kind=="collect":
   for i in range(4):star(p+Vector2.from_angle(i*TAU/4+u)*radius,2*fade,c)
   continue
  for i in range(7 if fx.gun!=1 else 11):
   var dir=Vector2.from_angle(i*2.399+fx.gun)
   line(p+dir*radius*.55,p+dir*(radius+5*fade),Color(c,fade),1.3)
  if u<.4:star(p,(12 if fx.gun==3 else 8)*(1-u/.4),Color("fff1bd"))
  if fx.kind=="muzzle":
   for i in range(3):ellipse(p+Vector2(i*5-5,-u*16),Vector2(4,3)*(1+u),Color(.66,.85,.95,fade*.17))

func fx_check():
 set_process(false);test_mode=true
 for gun_id in range(4):
  reset_run();weapon=gun_id;aim=Vector2.RIGHT
  spawn_enemy();enemies[0].p=player+Vector2(80,0);enemies[0].hp=999;enemies[0].max=999
  shoot()
  check(bullets[0].gun==gun_id,"projectile preserves weapon identity")
  for frame in range(10):update_bullets(.016);update_effects(.016)
  check(combat_fx.size()>1,"cannon hit creates impact effect")
  queue_redraw();await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://captures/cannon-%d.png"%gun_id)
 reset_run();upgrades.ranks.shell=5
 for i in range(5):
  spawn_enemy();enemies[-1].p=player+Vector2(45+i*18,-30+sin(i*2)*20);enemies[-1].hp=999;enemies[-1].max=999
 for frame in range(100):upgrades.tick(self,.016)
 var hit_count=0
 for e in enemies:
  if e.hp<999:hit_count+=1
 check(hit_count>=3,"shell flies and ricochets across enemies")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/shell.png")
 reset_run();upgrades.ranks.bubble=1;spawn_enemy();enemies[0].p=player+Vector2(90,0)
 upgrades.tick(self,.016);enemies.clear()
 var start:Vector2=upgrades.shots[0].p
 upgrades.tick(self,.1)
 check(upgrades.shots[0].p.distance_to(start)>5,"bubble keeps moving after target dies")
 for frame in range(140):upgrades.tick(self,.016)
 check(upgrades.shots.is_empty(),"orphan projectile expires")
 reset_run();upgrades.ranks.bubble=1
 for i in range(2):
  spawn_enemy();enemies[-1].p=player+Vector2(50,i*30);enemies[-1].hp=999
 for frame in range(30):upgrades.tick(self,.016)
 check(enemies[0].hp<999 and enemies[1].hp<999,"bubble deals splash damage to adjacent enemies")
 for kind in ["xp","armor","health","clear"]:
  var count=combat_fx.size();collect_feedback(kind,3);check(combat_fx.size()==count+1,"pickup feedback "+kind)
 print("FX CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func clear_drop_allowed(roll:float)->bool:
 return not clearing and roll<CLEAR_DROP_CHANCE

func loadout_check():
 set_process(false);test_mode=true;reset_run()
 spawn_clock=999;shot_cd=999
 for i in range(3):
  spawn_enemy();enemies[-1].p=player+Vector2(60+i*25,0)
 enemies[-1].boss=true;enemies[-1].hp=1000;enemies[-1].max=1000
 spawn_enemy();enemies[-1].p=player+Vector2(500,0)
 bullets.append({"p":player,"v":Vector2.ZERO,"hostile":true,"life":1,"dmg":1})
 pickups=[{"p":player,"type":"clear","value":1}]
 update_game(.01)
 check(enemies.size()==2,"pickup immediately clears onscreen regular enemies only")
 check(enemies[0].boss and enemies[0].hp==700,"clear damages boss by thirty percent")
 check(bullets.is_empty(),"clear removes hostile bullets")
 check(pickups.filter(func(p):return p.type=="clear").is_empty(),"clear kills cannot drop replacement clears")
 pickups=[{"p":player,"type":"clear","value":1},{"p":player,"type":"clear","value":1}]
 update_game(.01)
 check(enemies[0].hp==100 and not pickups.any(func(p):return p.type=="clear"),"two simultaneous pickups both activate without storage")
 var drops=0
 for i in range(10000):
  if clear_drop_allowed(i/10000.0):drops+=1
 check(drops==200,"two percent drop threshold")
 reset_run();upgrades.choices=["hull"];upgrades.pending=1;state="upgrade";upgrades.choose(self,0)
 check(max_hp==120 and hp==120,"hull card grants maximum and current health")
 upgrades.ranks.blast=5
 check(upgrades.area_scale()>1.5,"blast ability enlarges damage areas")
 reset_run();upgrades.ranks={"bubble":2,"mine":2,"escort":2,"shell":2,"starfish":2,"power":2,"blast":2,"impact":2,"magnet":2,"repair":2,"hull":2}
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/loadout-six.png")
 upgrades.pending=1;upgrades.offer(self);upgrades.choices=["battery","flare","impact"]
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/new-upgrades.png")
 print("LOADOUT CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func identity_check():
 set_process(false);test_mode=true
 check(not upgrades.INFO.has("shield") and not upgrades.INFO.has("speed") and not upgrades.INFO.has("haste"),"removed shield and acceleration cards")
 reset_run();upgrades.ranks.battery=1;spawn_enemy();enemies[0].p=player+Vector2(100,0);enemies[0].hp=999
 upgrades.tick(self,.1);check(enemies[0].hp==999 and upgrades.zones.size()==1,"mortar telegraphs before damage")
 upgrades.tick(self,.4);queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/mortar.png")
 enemies[0].p+=Vector2(0,100);upgrades.tick(self,.7)
 check(enemies[0].hp==999,"moving away evades fixed mortar landing")
 enemies[0].p=player+Vector2(100,0);upgrades.timers.battery=0;upgrades.tick(self,.01);upgrades.tick(self,1.1)
 check(enemies[0].hp<999,"mortar damages at impact")
 reset_run();upgrades.ranks.flare=1;spawn_enemy();enemies[0].p=player+Vector2(90,0);enemies[0].hp=999
 upgrades.tick(self,.3);check(enemies[0].hp==999,"oil flask cannot burn during flight")
 upgrades.tick(self,.4);upgrades.tick(self,.3);var health:float=enemies[0].hp
 upgrades.tick(self,.5);check(enemies[0].hp<health,"oil burns repeatedly")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/oil-lantern.png")
 enemies[0].p+=Vector2(0,100);health=enemies[0].hp;upgrades.tick(self,.5)
 check(enemies[0].hp==health,"leaving oil stops damage")
 reset_run();upgrades.ranks.escort=3;spawn_enemy();enemies[0].p=player+Vector2(56,0);enemies[0].hp=999
 upgrades.tick(self,.01)
 check(enemies[0].hp<999 and bullets.is_empty(),"ram boats deal contact damage without firing")
 reset_run();upgrades.ranks.mine=1;spawn_enemy();enemies[0].p=player+Vector2(20,0);enemies[0].hp=999
 upgrades.tick(self,.1);check(enemies[0].hp==999,"mine must arm first")
 enemies[0].p=upgrades.shots[0].landing
 upgrades.tick(self,.6);check(enemies[0].hp<999,"armed mine detonates on proximity")
 reset_run();upgrades.ranks.impact=4;spawn_enemy();enemies[0].hp=999;damage_enemy(0,1,Vector2(40,0))
 check(enemies[0].knock.x>=80,"impact ability increases knockback")
 reset_run();upgrades.pending=1;upgrades.offer(self);upgrades.choices=["escort","battery","flare"]
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/weapon-identities.png")
 print("IDENTITY CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func weapon_demo():
 reset_run();muted=false
 for segment in range(4):
  enemies.clear();bullets.clear();upgrades.reset();hp=100;armor=100
  player=Vector2(620,1010);cam=player;velocity=Vector2.ZERO
  var title=""
  match segment:
   0:upgrades.ranks={"battery":3,"blast":2};title="DEMO 1 / MORTAR: MARK > LOB > IMPACT"
   1:upgrades.ranks={"flare":3,"mine":3};title="DEMO 2 / OIL ZONES + ARMED MINES"
   2:upgrades.ranks={"escort":3,"starfish":3};title="DEMO 3 / RAM FLEET + RETURNING STAR"
   3:upgrades.ranks={"bubble":3,"shell":3};title="DEMO 4 / SPLASH BUBBLES + RICOCHET SHELL"
  for frame in range(240):
   if frame%60==0:
    for j in range(3):
     spawn_enemy()
     var pos=player+Vector2.from_angle(-PI/2+j*.9)*110
     enemies[-1].p=pos if not solid(pos,18) else player+Vector2(0,100)
     enemies[-1].hp=160;enemies[-1].max=160
   # Input events use the same physical movement path as normal play.
   for key in [KEY_W,KEY_S,KEY_A,KEY_D]:
    var e=InputEventKey.new();e.physical_keycode=key
    e.pressed=(key==KEY_W and frame<90) or (key==KEY_S and frame>=120 and frame<210)
    Input.parse_input_event(e)
   if state=="upgrade":upgrades.choose(self,0)
   if state=="dead":break
   message=title;message_left=1
   queue_redraw()
   await RenderingServer.frame_post_draw
  print("DEMO segment ",segment+1," kills=",kills," hull=",hp)
 for key in [KEY_W,KEY_S,KEY_A,KEY_D]:
  var e=InputEventKey.new();e.physical_keycode=key;e.pressed=false;Input.parse_input_event(e)
 print("WEAPON DEMO COMPLETE")
 get_tree().quit()

func combo_fixture(ids:Array):
 reset_run();spawn_clock=999
 for id in ids:upgrades.ranks[id]=1;upgrades.timers[id]=999

func combo_check():
 set_process(false);test_mode=true
 combo_fixture(["bubble"])
 check(upgrades.combos.eligible(upgrades.ranks).is_empty(),"combination requires both weapons")
 upgrades.ranks.flare=1;upgrades.pending=1;upgrades.offer(self)
 check("steam" in upgrades.choices,"eligible combination appears in upgrade choices")
 var count=upgrades.ranks.size();upgrades.choose(self,upgrades.choices.find("steam"))
 check(upgrades.combos.unlocked.has("steam") and upgrades.ranks.size()==count,"unlock takes no equipment slot")
 check(upgrades.combos.eligible(upgrades.ranks).is_empty(),"unlocked combination cannot repeat")
 combo_fixture(["bubble","flare"]);upgrades.combos.unlocked.steam=true
 spawn_enemy();enemies[0].p=player+Vector2(80,0);enemies[0].hp=999;enemies[0].max=999
 upgrades.zones.append({"kind":"oil","p":enemies[0].p,"origin":player,"time":0.0,"life":10.0,"radius":45.0,"damage":0.0,"pulse":999.0})
 upgrades.shots.append({"kind":"bubble","p":player+Vector2(50,0),"v":Vector2(145,0),"life":2.0,"damage":20.0,"r":1})
 upgrades.tick(self,.016)
 check(upgrades.combos.proc_counts.get("steam",0)==1 and upgrades.shots.is_empty(),"bubble touching oil converts once into steam")
 var health:float=enemies[0].hp;damage_enemy(0,20)
 check(is_equal_approx(health-enemies[0].hp,25),"steam increases subsequent damage by 25 percent")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/combo-steam.png")
 upgrades.phase+=3.1;health=enemies[0].hp;damage_enemy(0,20)
 check(is_equal_approx(health-enemies[0].hp,20),"steam vulnerability expires")
 combo_fixture(["mine","flare"]);upgrades.combos.unlocked.firechain=true
 spawn_enemy();enemies[0].p=player+Vector2(40,0);enemies[0].hp=999;enemies[0].max=999
 for i in range(3):upgrades.shots.append({"kind":"mine","p":player+Vector2(40+i*50,0),"life":7.0,"damage":20.0,"r":1})
 upgrades.shots.append({"kind":"mine","p":player+Vector2(145,10),"life":8.0,"damage":20.0,"r":1})
 for step in range(32):upgrades.tick(self,.016)
 check(upgrades.combos.proc_counts.get("firechain",0)==3,"armed mine chain detonates each mine once")
 check(upgrades.zones.size()==3 and upgrades.shots.size()==1,"mine chain leaves fire and excludes unarmed mine")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/combo-firechain.png")
 combo_fixture(["starfish","shell"]);upgrades.combos.unlocked.shards=true
 for i in range(3):
  spawn_enemy();enemies[-1].p=player+Vector2(35+i*38,i*10);enemies[-1].hp=999;enemies[-1].max=999
 upgrades.shots.append({"kind":"starfish","p":player+Vector2(15,0),"v":Vector2(180,0),"life":1.8,"damage":30.0,"r":1,"visited":[],"returning":false})
 upgrades.tick(self,.016)
 check(upgrades.shots.filter(func(s):return s.get("fragment",false)).size()==3,"starfish contact spawns three shell fragments")
 var procs=upgrades.combos.proc_counts.get("shards",0)
 upgrades.shots=upgrades.shots.filter(func(s):return s.kind!="starfish")
 for step in range(10):upgrades.tick(self,.016)
 check(upgrades.combos.proc_counts.get("shards",0)==procs,"fragments cannot recursively create fragments")
 check(enemies[1].hp<999 or enemies[2].hp<999,"shell fragments damage adjacent enemies")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/combo-shards.png")
 combo_fixture(["bubble","flare","mine","starfish","shell","power","hull","repair","magnet","blast","impact"])
 for id in upgrades.ranks:upgrades.ranks[id]=5
 owned=[true,true,true,true]
 upgrades.pending=1;upgrades.offer(self)
 check(upgrades.choices.size()==1 and upgrades.combos.RECIPES.has(upgrades.choices[0]),"combination remains available with full maxed equipment")
 upgrades.choices=["steam","firechain","shards"];level=12
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/combo-cards.png")
 reset_run();check(upgrades.combos.unlocked.is_empty() and upgrades.combos.effects.is_empty(),"new run clears combination unlocks and effects")
 test_mode=false
 var recorder=AudioEffectRecord.new();var slot=AudioServer.get_bus_effect_count(0)
 AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
 for cue in ["combo_steam","combo_chain","combo_shards"]:
  sfx(cue);await get_tree().create_timer(.8).timeout
 recorder.set_recording_active(false);recorder.get_recording().save_to_wav("res://captures/combo-audio.wav");AudioServer.remove_bus_effect(0,slot)
 print("COMBO CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func combo_demo():
 muted=false
 var ids=["steam","firechain","shards"]
 var labels=["BOILING BUBBLES / STEAM + VULNERABILITY","BURNING MINEFIELD / CHAIN + FIRE","SHELL STORM / STARFISH + BOUNCING FRAGMENTS"]
 for segment in range(3):
  reset_run();spawn_clock=999
  var id=ids[segment]
  for arm in upgrades.combos.RECIPES[id][2]:upgrades.ranks[arm]=3
  upgrades.combos.unlocked[id]=true
  # Demonstration starts with an armed mine line; subsequent mines use normal cooldowns.
  if id=="firechain":
   for i in range(3):upgrades.shots.append({"kind":"mine","p":player+Vector2(-40+i*40,-30),"life":7.3,"damage":71.0,"r":3})
  for frame in range(270):
   if frame%75==0:
    for j in range(4):
     spawn_enemy()
     var pos=player+Vector2(-65+j*42,-95-float(j%2)*20)
     enemies[-1].p=pos if not solid(pos,18) else player+Vector2(0,-90)
     enemies[-1].hp=230;enemies[-1].max=230
   for key in [KEY_W,KEY_S]:
    var e=InputEventKey.new();e.physical_keycode=key
    e.pressed=(key==KEY_W and frame<60) or (key==KEY_S and frame>=100 and frame<170)
    Input.parse_input_event(e)
   if state=="upgrade":upgrades.choose(self,0)
   clock+=1.0/30;update_game(1.0/30);bgm.update_mix(state,muted,false,1.0/30)
   message=labels[segment];message_left=1
   queue_redraw();await RenderingServer.frame_post_draw
  print("COMBO DEMO ",id," triggers=",upgrades.combos.proc_counts.get(id,0)," kills=",kills," hull=",hp)
 for key in [KEY_W,KEY_S]:
  var e=InputEventKey.new();e.physical_keycode=key;e.pressed=false;Input.parse_input_event(e)
 print("COMBO DEMO COMPLETE")
 get_tree().quit()

func bgm_check():
 reset_run();test_mode=false
 await get_tree().create_timer(.6).timeout
 check(bgm.playing and bgm.gain>0,"music plays during battle")
 muted=true;await get_tree().process_frame;await get_tree().process_frame
 check(bgm.stream_paused,"M mute pauses music")
 muted=false;await get_tree().process_frame;await get_tree().process_frame
 check(not bgm.stream_paused,"M resumes music")
 state="upgrade";await get_tree().create_timer(.5).timeout
 check(bgm.gain<=.101,"upgrade cards duck music")
 check(bgm.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and bgm.stream.loop_end>0,"BGM loops full composition")
 print("BGM CHECK DONE failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func mount_check():
 set_process(false);test_mode=true
 reset_run();upgrades.ranks={"bubble":2,"mine":2,"shell":2,"battery":2,"flare":2}
 heading=.35;queue_redraw()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/weapon-mounts.png")
 upgrades.ranks={"starfish":2,"escort":2,"shell":2,"battery":2,"flare":2}
 heading=2.4;queue_redraw()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/weapon-mounts-turn.png")
 print("MOUNT CAPTURE PASS")
 get_tree().quit()

func pressure_demo():
 for stage in range(3):
  reset_run();elapsed=stage*120.0;spawn_clock=0;invulnerable=999
  upgrades.ranks={"flare":2,"mine":2,"battery":2}
  for i in range(10+stage*6):spawn_enemy()
  var initial_kills=kills
  for frame in range(180):
   if state=="upgrade":upgrades.choose(self,0)
   message="PRESSURE PREVIEW / %d MIN"%(stage*2);message_left=1
   queue_redraw();await RenderingServer.frame_post_draw
   if frame==90:get_viewport().get_texture().get_image().save_png("res://captures/pressure-%d.png"%stage)
  print("PRESSURE stage=",stage," enemies=",enemies.size()," kills=",kills-initial_kills," fps=",Engine.get_frames_per_second())
 get_tree().quit()

func draw_cached_creature(e:Dictionary)->bool:
 if legacy_render:return false
 var species:String=e.get("species","ship")
 var cached_hit=species!="ship" and e.hit_pose>0
 if e.boss or (not cached_hit and (e.windup>0 or e.recover>0 or e.flash>0 or e.get("dash_left",0.0)>0)) or (species=="ship" and e.hit_pose>0):return false
 var key=species
 if key=="octopus" and int(e.kind)%4==0:key="octopus_coral"
 if cached_hit:key+="_hit"
 if not creature_atlases.has(key):
  var path="res://assets/creatures/%s.png"%key
  if not ResourceLoader.exists(path):return false
  creature_atlases[key]=load(path)
 var frame=int(fposmod(e.heading if species=="ship" else e.anim_clock,TAU)/TAU*128)%128
 if species=="ship":
  var size=.72/.84 if int(e.kind)%3==0 else 1.0
  var rocking=sin(clock*1.8+e.p.x*.05)*.018+sin(e.anim_clock*3.3)*.035
  draw_set_transform(render_offset+e.p+Vector2(0,sin(e.anim_clock*3.3)*1.3),rocking,Vector2.ONE*size)
  draw_texture_rect_region(creature_atlases[key],Rect2(-40,-40,80,80),Rect2((frame%16)*160,(frame/16)*160,160,160))
  draw_set_transform(render_offset)
  return true
 if cached_hit:
  var h=clampf(e.hit_pose/.3,0,1)
  var stretch=Vector2((1+h*.12)/1.06,(1-h*.15)/.925) if species=="octopus" else Vector2((1+h*.12)/1.06,(1-h*.12)/.94)
  var shift=Vector2(sin(h*17)*h*2-sin(8.5),0) if species=="octopus" else Vector2.ZERO
  draw_set_transform(render_offset+e.p+shift,0,stretch)
  draw_texture_rect_region(creature_atlases[key],Rect2(-40,-40,80,80),Rect2((frame%16)*160,(frame/16)*160,160,160),Color(1.12,1.12,1.12) if e.flash>0 else Color.WHITE)
  draw_set_transform(render_offset)
 else:
  draw_texture_rect_region(creature_atlases[key],Rect2(e.p-Vector2(40,40),Vector2(80,80)),Rect2((frame%16)*160,(frame/16)*160,160,160))
 return true

func bake_enemies():
 set_process(false);test_mode=true
 get_window().content_scale_size=Vector2i(1280,640)
 get_window().size=Vector2i(2560,1280)
 get_viewport().transparent_bg=true
 terrain_canvas.hide()
 DirAccess.make_dir_recursive_absolute("res://assets/creatures")
 for species in ["octopus","octopus_coral","jellyfish","crab","ship","octopus_hit","octopus_coral_hit","jellyfish_hit","crab_hit","octopus_down","octopus_coral_down","jellyfish_down","crab_down"]:
  bake_creature=species;queue_redraw()
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://assets/creatures/%s.png"%species)
  print("BAKED ",species)
 get_tree().quit()

func perf_stress():
 set_process(false);reset_run();rng.seed=20261105;spawn_clock=999;invulnerable=999
 upgrades.ranks={"bubble":3,"mine":3,"battery":3,"flare":3,"starfish":3}
 upgrades.combos.unlocked={"steam":true,"firechain":true}
 if OS.get_cmdline_user_args().has("--perf-signature"):
  weapon=3;owned[3]=true
  upgrades.ranks={"bubble":3,"mine":3,"shell":3,"flare":3,"starfish":3}
  upgrades.combos.unlocked.shards=true
 if OS.get_cmdline_user_args().has("--perf-max"):
  for id in upgrades.ranks:upgrades.ranks[id]=5
 for i in range(32):
  spawn_enemy();enemies[-1].p=player+Vector2.from_angle(i*TAU/32)*130
  enemies[-1].hp=100000;enemies[-1].max=100000
 var intervals:Array=[];var last=Time.get_ticks_usec()
 for frame in range(390):
  if OS.get_cmdline_user_args().has("--perf-churn") and frame%15==0:
   damage_enemy(0,1000000);spawn_enemy();enemies[-1].p=player+Vector2.from_angle(frame*.31)*130;enemies[-1].hp=100000;enemies[-1].max=100000
  if state=="upgrade":upgrades.choose(self,0)
  clock+=1.0/60;update_game(1.0/60);queue_redraw()
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec()
  if frame>=30:intervals.append((now-last)/1000.0)
  last=now
  if frame==389:get_viewport().get_texture().get_image().save_png("res://captures/performance-stress.png")
 var total=0.0
 for ms in intervals:total+=ms
 intervals.sort()
 print("STRESS enemies=",enemies.size()," fps=",intervals.size()*1000/total," p95_ms=",intervals[int(intervals.size()*.95)]," weapons=",upgrades.ranks.size()+1," zones=",upgrades.zones.size())
 get_tree().quit()

func signature_check():
 set_process(false);test_mode=true;reset_run();rng.seed=77
 weapon=3;aim=Vector2.RIGHT
 for i in range(5):
  spawn_enemy();enemies[-1].p=player+Vector2(50+i*28,0);enemies[-1].hp=1000
 shoot()
 for i in range(24):update_bullets(.016)
 check(enemies[0].hp==910 and enemies[3].hp==910 and enemies[4].hp==1000,"heavy shot pierces exactly four targets")
 reset_run();weapon=0;aim=Vector2.RIGHT
 for i in range(2):
  spawn_enemy();enemies[-1].p=player+Vector2(50+i*35,0);enemies[-1].hp=1000
 shoot()
 for i in range(24):update_bullets(.016)
 check(enemies[0].hp==958 and enemies[1].hp==1000,"basic cannon remains single target")
 combo_fixture(["shell"]);upgrades.ranks.shell=3;upgrades.timers.shell=0
 for i in range(3):
  spawn_enemy();enemies[-1].p=player+Vector2(55+i*35,(i%2)*45);enemies[-1].hp=1000
 for i in range(120):upgrades.tick(self,1.0/60)
 check(enemies.all(func(e):return e.hp<1000),"shell bounces through separated targets")
 for i in range(100):upgrades.add_path(Vector2.ZERO,Vector2.ONE,"shell",i)
 check(upgrades.paths.size()==24,"trajectory history is bounded")
 upgrades.tick(self,1.0)
 check(upgrades.paths.size()<=1,"trajectory history expires")
 print("SIGNATURE CHECK failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func signature_demo():
 set_process(false)
 var labels=["HEAVY CANNON / PIERCE UP TO 4","SHELL / FOLLOW THE BOUNCE PATH","STEAM / PURPLE MARK = +25% DAMAGE","FIRE CHAIN / WATCH THE FUSE TRAVEL","SHELL STORM / 3 BOUNCING FRAGMENTS"]
 for segment in ([3] if OS.get_cmdline_user_args().has("--fire-demo") else range(5)):
  reset_run();rng.seed=400+segment;spawn_clock=999;invulnerable=999;muted=false
  var loadouts=[[],["shell"],["bubble","flare"],["mine","flare"],["starfish","shell"]]
  for id in loadouts[segment]:upgrades.ranks[id]=3
  if segment==0:weapon=3;owned[3]=true
  if segment>=2:upgrades.combos.unlocked[["steam","firechain","shards"][segment-2]]=true
  for j in range(8):
   spawn_enemy()
   enemies[-1].p=player+Vector2(65+(j%4)*30,-60+(j/4)*90)
   if segment==0:enemies[-1].p=player+Vector2(65+(j%4)*28,(j/4)*60)
   enemies[-1].hp=300;enemies[-1].max=300
  if segment==3:
   for j in range(3):upgrades.shots.append({"kind":"mine","p":player+Vector2(60+j*48,-35),"life":7.0,"damage":71.0,"r":3})
  for frame in range(240):
   if frame%90==0:
    spawn_enemy();enemies[-1].p=player+Vector2(150,0);enemies[-1].hp=250;enemies[-1].max=250
   if state=="upgrade":upgrades.choose(self,0)
   clock+=1.0/30;update_game(1.0/30);bgm.update_mix(state,muted,false,1.0/30)
   message=labels[segment];message_left=1
   queue_redraw();await RenderingServer.frame_post_draw
   if frame==100:get_viewport().get_texture().get_image().save_png("res://captures/signature-%d.png"%segment)
  print("SIGNATURE DEMO segment=",segment," kills=",kills," combos=",upgrades.combos.proc_counts)
 print("SIGNATURE DEMO COMPLETE")
 get_tree().quit()

func no_port_check():
 set_process(false);test_mode=true;reset_run()
 upgrades.ranks={"bubble":5,"mine":5,"shell":5,"flare":5,"starfish":5,"power":5,"hull":5,"repair":5,"magnet":5,"blast":5,"impact":5}
 upgrades.combos.unlocked={"steam":true,"firechain":true,"shards":true}
 upgrades.pending=1;upgrades.offer(self)
 check(upgrades.choices.size()==3 and upgrades.choices.all(func(id):return upgrades.CANNONS.has(id)),"cannon cards available even with full equipment")
 upgrades.choices=["grapeshot","swivel","heavy"];queue_redraw()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/cannon-upgrade-cards.png")
 for id in ["grapeshot","swivel","heavy"]:
  upgrades.pending=1;upgrades.choices=[id];state="upgrade";upgrades.choose(self,0)
  check(owned[upgrades.CANNONS[id]] and weapon==upgrades.CANNONS[id] and upgrades.ranks.size()==11,"cannon unlock equips without consuming slots: "+id)
 upgrades.pending=1;upgrades.offer(self)
 check(upgrades.choices==["supplies"],"unlocked cannons never repeat")
 reset_run();spawn_clock=999
 for i in range(3):spawn_enemy();damage_enemy(enemies.size()-1,10000)
 check(not pickups.any(func(p):return p.type in ["ammo","cash"]),"kills drop no obsolete ammo or coins")
 owned=[true,true,true,true];hp=50;armor=20
 pickups=[{"p":player,"type":"health","value":20},{"p":player,"type":"armor","value":25}]
 update_game(.01)
 check(hp==70 and armor==45,"salvage repairs hull and armor")
 var key=InputEventKey.new();key.keycode=KEY_E;key.pressed=true;_unhandled_input(key)
 check(state=="play","E no longer opens harbor shop")
 reset_run();check(owned==[true,false,false,false],"new voyage resets cannon unlocks")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/no-port-gameplay.png")
 print("NO PORT CHECK failures=",test_failures)
 get_tree().quit(0 if test_failures==0 else 1)

func controls_check():
 set_process(false);test_mode=true
 var counts:Array=[]
 for fps in [60,20]:
  reset_run();rng.seed=421;shot_cd=999;invulnerable=999
  for frame in range(fps*10):_process(1.0/fps)
  counts.append(enemies.size())
  check(absf(elapsed-10)<.02,"simulation clock preserves ten seconds at %d FPS"%fps)
 check(counts[0]==counts[1],"spawn count consistent across frame rates")
 reset_run();owned=[true,true,true,true];action("cannon3")
 check(weapon==3,"clicking a cannon equips it")
 var key=InputEventKey.new();key.keycode=KEY_2;key.pressed=true;_unhandled_input(key)
 check(weapon==1,"number keys still select cannons")
 test_mode=false;old_state="play";state="pause";action("music")
 _process(.02);check(music_muted and bgm.stream_paused and not muted,"music button pauses BGM without muting combat sounds")
 action("music");_process(.02);check(not music_muted and not bgm.stream_paused,"music button resumes BGM")
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/pause-music-button.png")
 state="play";weapon=3;queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/cannon-hud.png")
 pickups.clear();drop_pickup(player,"xp",3);drop_pickup(player+Vector2(3,0),"xp",6)
 check(pickups.size()==1 and pickups[0].value==9,"nearby salvage merges without losing value")
 test_mode=false;bgm.stop()
 var recorder=AudioEffectRecord.new();var slot=AudioServer.get_bus_effect_count(0)
 AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
 upgrades.pending=1;upgrades.offer(self)
 await get_tree().create_timer(.9).timeout
 recorder.set_recording_active(false);recorder.get_recording().save_to_wav("res://captures/level-up.wav");AudioServer.remove_bus_effect(0,slot)
 check(state=="upgrade" and sounds.has("level_up"),"upgrade choice opens with dedicated cue")
 print("CONTROLS CHECK failures=",test_failures," spawn_counts=",counts)
 get_tree().quit(0 if test_failures==0 else 1)

func capture_tier_gallery():
 set_process(false);test_mode=true;tier_gallery=true
 queue_redraw();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://captures/weapon-levels.png")
 print("TIER GALLERY PASS")
 get_tree().quit()

func draw_tier_gallery():
 draw_set_transform(Vector2.ZERO);render_offset=Vector2.ZERO
 rect(Rect2(0,0,640,360),Color("278e91"))
 center("WEAPON GROWTH / LEVEL 1 - 3 - 5",Vector2(320,28),15,CREAM)
 var ids=["bubble","mine","starfish","shell","battery","flare","escort"]
 var labels=["BUBBLE","MINE","STARFISH","SHELL","MORTAR","OIL FIRE","ESCORT"]
 for col in range(7):center(labels[col],Vector2(83+col*80,54),8,CREAM)
 for row in range(3):
  var rank=1+row*2;var y=105+row*90
  rect(Rect2(4,y-35,632,77),Color(1,1,1,.035 if row%2==0 else .07))
  text("LV %d"%rank,Vector2(8,y+4),8,CREAM)
  for col in range(7):
   var id=ids[col];var p=Vector2(83+col*80,y)
   upgrades.ranks={};upgrades.shots=[];upgrades.zones=[];upgrades.phase=.9
   if id in ["bubble","mine","starfish","shell"]:
    upgrades.shots=[{"kind":id,"p":p,"v":Vector2(150,0),"r":rank,"life":7.0,"trail":[p-Vector2(26,0),p-Vector2(20,1),p-Vector2(14,0)]}]
    upgrades.world(self)
   elif id=="battery":
    upgrades.zones=[{"kind":"mortar","r":rank,"p":p+Vector2(12,20),"origin":p+Vector2(-12,20),"time":.17,"life":1.1,"radius":22.0}]
    upgrades.draw_zones(self)
   elif id=="flare":
    upgrades.zones=[{"kind":"oil","r":rank,"p":p+Vector2(0,12),"time":1.0,"life":4.0,"radius":26.0}]
    upgrades.draw_zones(self)
   else:
    draw_ship(p+Vector2(0,5),-.7,4,.42+row*.05,false,false,false,Vector2.ZERO)
    if row>0:star(p-Vector2(0,14+row*2),2+row,Color("f3d596"))
    center("x%d"%(1+rank/2),p+Vector2(0,28),8,CREAM)

func tier_demo():
 set_process(false)
 for group in range(2):
  for rank in [1,3,5]:
   reset_run();spawn_clock=999;invulnerable=999;muted=false;rng.seed=121
   for id in (["bubble","mine","battery","flare","starfish"] if group==0 else ["shell","escort"]):upgrades.ranks[id]=rank
   for j in range(12):
    spawn_enemy();enemies[-1].p=player+Vector2.from_angle(j*TAU/12)*110;enemies[-1].hp=500;enemies[-1].max=500
   for frame in range(150):
    if state=="upgrade":upgrades.choices=["supplies"];upgrades.choose(self,0)
    clock+=1.0/30;update_game(1.0/30);bgm.update_mix(state,muted,false,1.0/30)
    message="WEAPON LEVEL %d / %s"%[rank,"BUBBLE - MINE - STAR - MORTAR - FIRE" if group==0 else "SHELL - RAM FLEET"];message_left=1
    queue_redraw();await RenderingServer.frame_post_draw
   print("TIER DEMO group=",group," rank=",rank," kills=",kills)
 print("TIER DEMO COMPLETE")
 get_tree().quit()
