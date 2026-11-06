extends RefCounted
# Run-local automatic weapons and illustrated level-up cards.
const CANNONS={"grapeshot":1,"swivel":2,"heavy":3}
const INFO={
 "grapeshot":["Grapeshot cannon","Seven-pellet broadsides. Uses the main cannon slot.",Color("ef9875")],
 "swivel":["Rapid cannon","Rapid single shots. Uses the main cannon slot.",Color("80d7db")],
 "heavy":["Piercing cannon","Pierces four foes. Uses the main cannon slot.",Color("b6a0ed")],
 "starfish":["Returning star","Pierces foes, then returns to your boat.",Color("edbb8d")],
 "hull":["Sturdy hull","Gain 20 max hull and repair 20.",Color("a9ccbd")],
 "repair":["Repair crew","Repair hull automatically at sea.",Color("acd5a0")],
 "battery":["Deck mortar","Lob a bomb at a marked landing zone.",Color("e8b27d")],
 "flare":["Oil lantern","Leave a burning patch beneath foes.",Color("eb947b")],
 "bubble":["Bubble cannon","Big homing bubbles burst in an area.",Color("72cfc7")],
 "mine":["Star mines","Drop mines that burst on contact.",Color("edbd75")],
 "escort":["Ram fleet","Orbiting boats ram nearby enemies.",Color("ec9d89")],
 "shell":["Skipping shell","Ricochets between foes; watch its marked bounce path.",Color("e7ba88")],
 "power":["Power pearl","All weapons deal 15% more damage.",Color("e9a0ab")],
 "magnet":["Shell magnet","Collect loot from 30px farther away.",Color("8cbeb4")],
 "blast":["Wide splash","Blast and oil areas grow 12% larger.",Color("efc486")],
 "impact":["Heavy impact","Push enemies 25% farther on hit.",Color("b8aacb")]}
const ARMS=["bubble","mine","escort","shell","starfish","battery","flare"]
const WEAPON_SLOTS=6
const ABILITY_SLOTS=6
var oil_fire=preload("res://scripts/oil_fire.gd").new()
var combos=preload("res://scripts/voyage_combos.gd").new()
var ranks:Dictionary={}
var choices:Array=[]
var timers:Dictionary={}
var shots:Array=[]
var paths:Array=[]
var zones:Array=[]
var traces:Array=[]
var pending=0
var phase=0.0
var random=RandomNumberGenerator.new()

func reset():
 combos.reset()
 ranks.clear();choices.clear();timers.clear();shots.clear();paths.clear();zones.clear();traces.clear();pending=0;phase=0
 random.randomize()

func threshold(g)->int:return 12+(g.level-1)*6

func gain(g,amount:int):
 g.xp+=amount
 while g.xp>=threshold(g):
  g.xp-=threshold(g);g.level+=1;pending+=1

func offer(g):
 if pending<=0 or g.state!="play":return
 var pool:Array=[]
 var arms=0
 var passives=0
 for id in ranks:
  if id in ARMS:arms+=1
  else:passives+=1
 for id in INFO:
  if CANNONS.has(id):
   if not g.owned[CANNONS[id]]:pool.append(id)
   continue
  if int(ranks.get(id,0))>=5:continue
  if id in ARMS and not ranks.has(id) and arms>=WEAPON_SLOTS-1:continue # Base cannon occupies slot one.
  if id not in ARMS and not ranks.has(id) and passives>=ABILITY_SLOTS:continue
  pool.append(id)
 choices.clear()
 var combinations=combos.eligible(ranks)
 if not combinations.is_empty():choices.append(combinations[random.randi_range(0,combinations.size()-1)])
 while choices.size()<3 and not pool.is_empty():
  var i=random.randi_range(0,pool.size()-1);choices.append(pool.pop_at(i))
 if choices.is_empty():choices=["supplies"]
 g.state="upgrade";g.buttons.clear();g.sfx("level_up")

func choose(g,index:int):
 if g.state!="upgrade" or index<0 or index>=choices.size():return
 var id=choices[index]
 if combos.RECIPES.has(id):
  if not id in combos.eligible(ranks):return
  combos.unlocked[id]=true
 elif CANNONS.has(id):
  var cannon:int=CANNONS[id]
  if g.owned[cannon]:return
  g.owned[cannon]=true;g.weapon=cannon
 elif id=="supplies":g.hp=minf(g.max_hp,g.hp+40)
 else:
  ranks[id]=int(ranks.get(id,0))+1;timers[id]=0.0
  if id=="power":g.damage_boost+=.15
  if id=="hull":g.max_hp+=20;g.hp=minf(g.max_hp,g.hp+20)
 pending-=1;choices.clear();g.buttons.clear();g.state="play";g.sfx("pickup");offer(g)

func target(g,p:Vector2,reach:float)->Dictionary:
 var best:Dictionary={};var d=reach
 for e in g.enemies:
  var dist=p.distance_to(e.p)
  if dist<d and g.clear_water_line(p,e.p,3):best=e;d=dist
 return best

func tick(g,dt:float):
 phase+=dt
 combos.tick(dt)
 for path in paths:path.life-=dt
 paths=paths.filter(func(path):return path.life>0)
 for t in traces:t.life-=dt
 traces=traces.filter(func(t):return t.life>0)
 for id in ranks:
  timers[id]=float(timers.get(id,0))-dt
  if timers[id]>0:continue
  var rank:int=ranks[id]
  var foe=target(g,g.player,170)
  match id:
   "starfish":
    if foe.is_empty():continue
    shots.append({"p":g.player,"kind":"starfish","v":(foe.p-g.player).normalized()*180,"life":1.8,"damage":(22+rank*9)*g.damage_boost,"r":rank,"visited":[],"returning":false})
    timers[id]=2.5-rank*.15;g.sfx("shell_launch")
   "bubble":
    if foe.is_empty():continue
    for i in range(1+rank/2):
     shots.append({"p":g.player+Vector2(0,i*7),"kind":"bubble","v":(foe.p-g.player).normalized()*145,"life":2.0,"damage":(16+rank*8)*g.damage_boost,"r":rank})
    timers[id]=1.5-rank*.12;g.sfx("ink")
   "mine":
    shots.append({"origin":g.player,"landing":g.move_body(g.player,-Vector2.from_angle(g.heading)*28,3),"p":g.player,"kind":"mine","life":8.0,"damage":(35+rank*12)*g.damage_boost,"r":rank})
    timers[id]=3.5-rank*.3
   "escort":
    for i in range(1+rank/2):
     var p=g.player+Vector2.from_angle(phase*2.2+i*TAU/(1+rank/2))*56
     for e in g.enemies.duplicate():
      if e.p.distance_to(p)>24:continue
      var index=g.enemies.find(e)
      if index>=0:g.damage_enemy(index,(15+rank*6)*g.damage_boost,(e.p-g.player).normalized()*150)
      g.add_combat_fx(p,1,"impact");g.sfx("ship_hit")
    timers[id]=.28
   "shell":
    if foe.is_empty():continue
    shots.append({"p":g.player,"kind":"shell","last_hit":g.player,"bounces":0,"v":(foe.p-g.player).normalized()*230,"life":2.2,"damage":(20+rank*7)*g.damage_boost,"r":rank,"left":rank+1,"visited":[]})
    timers[id]=3.4-rank*.25;g.sfx("shell_launch")
   "repair":
    g.hp=minf(g.max_hp,g.hp+8+rank*4);timers[id]=12-rank
   "battery":
    if foe.is_empty():continue
    zones.append({"kind":"mortar","r":rank,"p":foe.p,"origin":g.player,"time":0.0,"life":1.1,"radius":(48+rank*4)*area_scale(),"damage":(65+rank*22)*g.damage_boost,"pulse":0.0})
    timers[id]=4.5-rank*.25;g.sfx("heavy_shot")
   "flare":
    if foe.is_empty():continue
    zones.append({"kind":"oil","r":rank,"flight":.65,"p":foe.p,"origin":g.player,"time":0.0,"life":3.5+rank*.3,"radius":(35+rank*4)*area_scale(),"damage":(6+rank*3)*g.damage_boost,"pulse":.25})
    timers[id]=6.5-rank*.3;g.sfx("shell_launch")
 for zone in zones:
  if zone.get("flight",0.0)>0:
   zone.flight=maxf(0,zone.flight-dt)
   if zone.flight<=0:g.add_combat_fx(zone.p,2,"impact");g.sfx("explosion")
   continue
  zone.time+=dt;zone.pulse-=dt
  var detonate=zone.kind=="mortar" and zone.time>=zone.life
  if detonate or (zone.kind=="oil" and zone.pulse<=0):
   zone.pulse=.45
   for e in g.enemies.duplicate():
    if e.p.distance_to(zone.p)>zone.radius or not g.clear_water_line(zone.p,e.p,3):continue
    var index=g.enemies.find(e)
    if index>=0:g.damage_enemy(index,zone.damage,(e.p-zone.p).normalized()*(100 if detonate else 0))
   if detonate:
    traces.append({"p":zone.p,"life":.4,"radius":zone.radius,"kind":"mortar","r":zone.get("r",1)});g.add_combat_fx(zone.p,3,"impact");g.sfx("heavy_hit")
 zones=zones.filter(func(z):return z.time<z.life)
 for s in shots:
  if s.has("v"):
   if not s.has("trail"):s["trail"]=[]
   s.trail.append(s.p)
   if s.trail.size()>7:s.trail.pop_front()
  if s.has("shard_cd"):s.shard_cd=maxf(0,s.shard_cd-dt)
  s.life-=dt
  if s.kind=="mine" and s.has("landing"):
   var deployment=clampf((8.0-s.life)/.6,0,1)
   s.p=s.origin.lerp(s.landing,deployment)-Vector2(0,sin(deployment*PI)*22)
  if s.life<=0:
   g.add_combat_fx(s.p,2,"collect");continue
  if s.kind=="starfish":
   if s.life<.95:
    if not s.returning:s.returning=true;s.visited.clear()
    s.v=(g.player-s.p).normalized()*220
   s.p+=s.v*dt
   if s.returning and s.p.distance_to(g.player)<12:s.life=0;continue
   if g.solid(s.p,2):s.life=0;continue
   for e in g.enemies.duplicate():
    if e in s.visited or e.p.distance_to(s.p)>24:continue
    s.visited.append(e)
    var idx=g.enemies.find(e)
    combos.fragment(g,self,s,e)
    if idx>=0:g.damage_enemy(idx,s.damage)
    g.add_combat_fx(s.p,1,"impact");g.sfx("shell_hit")
   continue
  if s.kind in ["bubble","shell"]:
   var foe=projectile_target(g,s)
   if not foe.is_empty():
    var speed=145 if s.kind=="bubble" else 230
    s.v=s.v.lerp((foe.p-s.p).normalized()*speed,minf(1,dt*7))
   # No target: retain velocity instead of freezing at the last location.
   s.p+=s.v*dt
  if g.solid(s.p,2):
   s.life=0;g.add_combat_fx(s.p,2,"collect");continue
  if s.kind=="bubble" and combos.steam(g,self,s):continue
  var forced=false
  if s.has("chain_fuse"):
   s.chain_fuse-=dt;forced=s.chain_fuse<=0
  if s.kind=="mine" and s.life>7.4:continue
  var hit=projectile_target(g,s,22 if s.kind!="mine" else 32)
  if hit.is_empty() and not forced:continue
  if s.kind=="shell":
   s.visited.append(hit);s.left-=1
   s["bounces"]=int(s.get("bounces",0))+1
   add_path(s.get("last_hit",s.p),hit.p,"shard" if s.get("fragment",false) else "shell",s.bounces)
   s["last_hit"]=hit.p
   var index=g.enemies.find(hit)
   if index>=0:g.damage_enemy(index,s.damage,s.v.normalized()*28)
   g.add_combat_fx(s.p,1,"impact");g.sfx("shell_hit",1.0+minf(.35,s.bounces*.08))
   var next=projectile_target(g,s,145)
   if s.left<=0 or next.is_empty():s.life=0
   else:s.v=(next.p-s.p).normalized()*230
   continue
  s.life=0
  if s.kind=="mine":combos.ignite(g,self,s)
  var radius=(65.0 if s.kind=="mine" else 38.0+s.r*5)*area_scale()
  for i in range(g.enemies.size()-1,-1,-1):
   if g.enemies[i].p.distance_to(s.p)<radius:
    var push=(g.enemies[i].p-s.p).normalized()*80 if s.kind=="bubble" else Vector2.ZERO
    g.damage_enemy(i,s.damage,push)
  g.add_combat_fx(s.p,2 if s.kind=="bubble" else 1,"impact")
  traces.append({"p":s.p,"life":.4,"radius":radius,"kind":s.kind,"r":s.r})
  g.sparks(s.p,INFO[s.kind][2],6);g.sfx("bubble_burst" if s.kind=="bubble" else "explosion")
 shots=shots.filter(func(s):return s.life>0)
 shots.append_array(combos.pending_shots);combos.pending_shots.clear()

func world(g):
 for s in shots:
  var rank=clampi(int(s.get("r",1)),1,5)
  var tier=(rank-1)/2
  var size=1.0+(rank-1)*.065
  var trail:Array=s.get("trail",[])
  var color=Color("a6ede3") if s.kind=="bubble" else Color("f4c38a")
  for j in range(1,trail.size()):
   var weight=float(j)/trail.size()
   if trail[j].distance_to(trail[j-1])<40:g.line(trail[j-1],trail[j],Color(color,weight*.4),weight*(5 if s.kind=="starfish" else 3)*size)
  match s.kind:
   "bubble":
    var pulse=(1+sin(phase*9)*.06)*size
    g.soft_shadow(s.p+Vector2(2,7),Vector2(12,5),.16)
    g.ellipse(s.p,Vector2(15,15)*pulse,Color(.52,.92,.84,.16))
    g.material_ellipse(s.p,Vector2(11,12)*pulse,Color("6bc9c4").lerp(Color("45b5c7"),tier*.18))
    if tier>0:g.draw_arc(s.p,13*pulse,.4,2.4,12,Color("f3c7a1"),1+tier*.4,true)
    g.draw_arc(s.p,11*pulse,-2.8,-1.1,18,Color("e9fff1"),2,true)
    g.draw_arc(s.p,10*pulse,.1,1.1,12,Color("e9b6c7"),1.5,true)
    g.ellipse(s.p+Vector2(-3,-4),Vector2(3,2),Color(.95,1,.93,.8))
    for j in range(2):g.draw_arc(s.p-s.v.normalized()*(17+j*8),3-j,0,TAU,12,Color(.8,1,.93,.5-j*.15),1,true)
   "mine":
    var ready=s.life<=7.4;var bob=sin(phase*3+s.p.x)*1.5
    g.draw_arc(s.p,14,0,TAU,24,Color(.8,.98,.87,.35),1,true)
    g.material_ellipse(s.p+Vector2(0,bob),Vector2(10,7)*size,Color("dbab70"))
    for j in range(5):
     var dir=Vector2.from_angle(j*TAU/5)
     g.line(s.p+dir*7*size,s.p+dir*11*size,Color("a77a55"),3)
    g.material_ellipse(s.p+Vector2(0,-4+bob),Vector2(7,5)*size,Color("efcc91"))
    g.draw_circle(s.p+Vector2(0,-8+bob),2,Color("ef8b68") if ready and sin(phase*8)>0 else Color("a6a591"))
    if tier>0:
     g.line(s.p+Vector2(-7,1)*size,s.p+Vector2(7,1)*size,Color("eaf1c6"),1.5+tier*.5)
     for gem in range(tier):g.material_ellipse(s.p+Vector2(-3+gem*6,-3)*size,Vector2(1.7,2),Color("72d8cd"))
    if ready:g.draw_arc(s.p,15+fmod(phase*10,10),0,TAU,24,Color(1,.8,.45,(1-fmod(phase*10,10)/10)*.25),1,true)
   "starfish":
    g.draw_arc(s.p,15*size,phase*8,phase*8+PI*1.3,22,Color(1,.8,.5,.5),2,true)
    g.draw_set_transform(g.render_offset+s.p,phase*8)
    icon(g,s.kind,Vector2.ZERO,.48*size);g.draw_set_transform(g.render_offset)
    if tier>0:g.material_ellipse(s.p,Vector2(3+tier,3+tier),Color("79d9d0"))
    if tier==2:g.star(s.p-s.v.normalized()*23,5,Color("f7df9f"))
   "shell":
    var scale=.24 if s.get("fragment",false) else .43*size
    g.draw_set_transform(g.render_offset+s.p,s.v.angle()+PI*.5)
    icon(g,"shell",Vector2.ZERO,scale);g.draw_set_transform(g.render_offset)
    if tier>0 and not s.get("fragment",false):
     g.material_ellipse(s.p,Vector2(2+tier,2+tier),Color("f7d37e"))
     g.line(s.p-s.v.normalized()*18,s.p-s.v.normalized()*(24+tier*6),Color("f3ddab"),tier+1)
    g.draw_arc(s.p,8 if s.get("fragment",false) else 14*size,phase*6,phase*6+2,14,Color(1,.88,.64,.55),1.5,true)
 if ranks.has("escort"):
  var count=1+int(ranks.escort)/2
  var tier=(int(ranks.escort)-1)/2
  for i in range(count):
   var angle=phase*2.2+i*TAU/count
   var p=g.player+Vector2.from_angle(angle)*56
   var wake=PackedVector2Array()
   for j in range(12):wake.append(g.player+Vector2.from_angle(angle-j*.035)*56)
   g.draw_polyline(wake,Color(.85,.99,.91,.4),3+tier,true)
   g.draw_ship(p,angle+PI*.5,4,.42+tier*.05,false,false,false,g.render_offset)
   if tier>0:g.star(p-Vector2(0,14+tier*2),2+tier,Color("f3d596"))
  g.draw_set_transform(g.render_offset)

func icon(g,id:String,p:Vector2,size:float=1.0):
 # Original vector illustrations: same shaded shapes as the game, not text placeholders.
 var c=INFO[id][2] if INFO.has(id) else Color("80e7b5")
 g.soft_shadow(p+Vector2(3,20)*size,Vector2(26,8)*size,.2)
 match id:
  "cannon","grapeshot","swivel","heavy":
   g.material_ellipse(p+Vector2(0,15)*size,Vector2(26,10)*size,Color("668f91"))
   var barrels=3 if id=="grapeshot" else 1
   for j in range(barrels):
    var start=p+Vector2((j-(barrels-1)*.5)*10,8)*size
    var tip=start+Vector2(10,-33)*size
    g.line(start,tip,c,(9 if id!="heavy" else 14)*size)
    g.material_ellipse(tip,Vector2(5 if id!="heavy" else 8,4)*size,Color("3d526b"))
   if id=="swivel":
    for j in range(3):g.line(p+Vector2(-24,5-j*9)*size,p+Vector2(-12,5-j*9)*size,c,3*size)
   elif id=="heavy":g.star(p+Vector2(23,-9)*size,9*size,Color("ffe797"))
  "bubble","hull":
   g.material_ellipse(p,Vector2(23,25)*size,c)
   g.draw_arc(p,20*size,-2.7,-1.2,20,Color("eefcff"),3*size,true)
   if id=="bubble":
    g.material_ellipse(p+Vector2(23,14)*size,Vector2(10,10)*size,c)
    g.material_ellipse(p+Vector2(-24,-16)*size,Vector2(6,6)*size,c)
   else:g.star(p,12*size,Color("eafaff"))
  "mine","starfish":
   g.star(p,31*size,c);g.material_ellipse(p,Vector2(17,17)*size,Color("f78e49"))
   for x in [-6,6]:g.ellipse(p+Vector2(x,-2)*size,Vector2(2,3)*size,Color("26486d"))
  "escort":
   g.material_ellipse(p+Vector2(0,15)*size,Vector2(28,11)*size,c)
   g.line(p+Vector2(0,13)*size,p-Vector2(0,29)*size,Color("386ba0"),3*size)
   g.smooth_polygon(PackedVector2Array([p+Vector2(-3,-28)*size,p+Vector2(-24,6)*size,p+Vector2(-3,6)*size]),Color("edfaff"))
   g.smooth_polygon(PackedVector2Array([p+Vector2(3,-26)*size,p+Vector2(24,4)*size,p+Vector2(3,4)*size]),Color("70c8f4"))
  "shell":
   g.material_ellipse(p,Vector2(26,21)*size,c)
   for i in range(5):
    var tip=p+Vector2.from_angle(-PI*.9+i*PI*.2)*24*size
    g.line(p+Vector2(0,17)*size,tip,Color("fff1d6"),2.5*size)
   g.material_ellipse(p+Vector2(0,17)*size,Vector2(8,5)*size,Color("f28a78"))
  "battery":
   g.material_ellipse(p+Vector2(0,14)*size,Vector2(27,10)*size,Color("5986ad"))
   g.line(p+Vector2(5,10)*size,p+Vector2(-9,-18)*size,c,16*size)
   g.material_ellipse(p+Vector2(-9,-18)*size,Vector2(9,5)*size,Color("355479"))
   g.star(p+Vector2(17,-23)*size,10*size,Color("ffd980"))
  "flare":
   for i in range(3):
    g.material_ellipse(p+Vector2((i-1)*12,4-abs(i-1)*5)*size,Vector2(10,23-abs(i-1)*5)*size,c)
   g.material_ellipse(p+Vector2(0,12)*size,Vector2(9,13)*size,Color("ffe393"))
  "blast":
   for i in range(3):g.draw_arc(p,(12+i*8)*size,0,TAU,32,Color(c,1-i*.2),3*size,true)
  "power":
   g.material_ellipse(p,Vector2(25,25)*size,c);g.star(p,16*size,Color("fff0c2"))
  "impact":
   for i in range(3):g.line(p+Vector2(-28,-14+i*14)*size,p+Vector2(24-i*5,-14+i*14)*size,c,6*size)
   g.star(p+Vector2(15,-2)*size,15*size,Color("f1fffb"))
  "magnet":
   g.draw_arc(p-Vector2(0,8)*size,20*size,0,PI,24,c,12*size,true)
   for x in [-20,20]:g.line(p+Vector2(x,-8)*size,p+Vector2(x,-22)*size,Color("ff849c"),12*size)
  _:
   g.heart(p,23*size,c)

func cards(g):
 g.rect(Rect2(0,0,640,360),Color(.12,.23,.21,.72))
 g.center("LEVEL %d  /  CHOOSE AN UPGRADE"%g.level,Vector2(320,39),17,Color("ecf9ff"))
 g.center("Battle paused - pick a card to continue",Vector2(320,58),9,Color("9ddbea"))
 for i in range(choices.size()):
  var id=choices[i];var x=39+i*190;var r=Rect2(x,78,182,232)
  var hover=r.has_point(g.cursor)
  g.round_box(Rect2(r.position+Vector2(0,4),r.size),Color("7e8d70"),Color("7e8d70"),0,14)
  g.round_box(r,Color("fff0ce"),Color("f4c46f") if hover else Color("ba9471"),3 if hover else 1,14)
  var is_combo=combos.RECIPES.has(id)
  var rank=int(ranks.get(id,0));var label="SUPPLIES" if id=="supplies" else ("NEW WEAPON" if id in ARMS else "NEW ABILITY") if rank==0 else "LEVEL %d > %d"%[rank,rank+1]
  if is_combo:label="COMBINATION / NO SLOT"
  elif CANNONS.has(id):label="MAIN CANNON / SHARED SLOT"
  g.center(label,Vector2(x+91,99),9,Color("526d62"))
  if is_combo:combos.illustration(g,self,id,Vector2(x+91,148))
  else:icon(g,id,Vector2(x+91,148),1.0)
  g.center(combos.RECIPES[id][0] if is_combo else INFO[id][0] if INFO.has(id) else "Salvaged supplies",Vector2(x+91,201),13,Color("3d4c47"))
  var desc=combos.RECIPES[id][1] if is_combo else INFO[id][1] if INFO.has(id) else "Repair 40 hull."
  # Keep descriptions within each card at the logical viewport size.
  var words=desc.split(" ");var row="";var y=222
  for word in words:
   if g.font.get_string_size(row+word,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x>156:
    g.center(row,Vector2(x+91,y),9,Color("6e7660"));row="";y+=13
   row+=word+" "
  g.center(row,Vector2(x+91,y),9,Color("6e7660"))
  var next=rank+1
  var detail="Automatic - no extra keys"
  match id:
   "bubble":detail="%d bubbles / %d damage"%[1+next/2,16+next*8] if next<5 else "MAX: 63px splash + knockback"
   "mine":detail="%d damage / %.1fs interval"%[35+next*12,3.5-next*.3]
   "escort":detail="%d rams / %d contact damage"%[1+next/2,15+next*6]
   "shell":detail="Up to %d targets / %d damage"%[1+next,20+next*7]
   "power":detail="Total bonus: +%d%% damage"%(next*15)
   "magnet":detail="Pickup reach: %dpx"%(48+next*30)
   "starfish":detail="%d damage / hits outbound + return"%(22+next*9)
   "blast":detail="+%d%% area radius"%(next*12)
   "impact":detail="+%d%% knockback"%(next*25)
   "hull":detail="+%d maximum hull"%(next*20)
   "repair":detail="%d hull every %ds"%[8+next*4,12-next]
   "battery":detail="%d damage / 1.1s landing delay"%(65+next*22)
   "flare":detail="%d damage per tick / %.1fs burn"%[6+next*3,3.5+next*.3]
  if CANNONS.has(id):detail="Auto-equip / switch with keys 1-4"
  if is_combo:
   var pair=combos.RECIPES[id][2]
   detail=INFO[pair[0]][0]+" + "+INFO[pair[1]][0]
  g.center(detail,Vector2(x+91,268),8,Color("7e725b"))
  g.round_box(Rect2(x+30,280,122,21),Color("f2c17e"),Color("f2c17e"),0,8)
  g.center("[%d] SELECT"%(i+1),Vector2(x+91,295),10,Color("3d4c47"))
  g.buttons.append({"id":"upgrade%d"%i,"rect":r})

func hud(g):
 combos.hud(g,self)
 # Four cannon images share the main weapon slot; locked modes remain legible.
 g.draw_string(g.font,Vector2(109,299),"CANNONS",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("dff7ff"))
 for cannon in range(4):
  var r=Rect2(108+cannon*36,305,32,39)
  var selected=g.weapon==cannon
  var unlocked=g.owned[cannon]
  g.round_box(r,Color("fff0ce") if unlocked else Color("76a9a5"),Color("f4bd69") if selected else Color("568b87"),2 if selected else 1,6)
  var p=r.position+Vector2(16,14)
  if cannon==0:icon(g,"cannon",p,.33)
  else:icon(g,["grapeshot","swivel","heavy"][cannon-1],p,.33)
  if not unlocked:
   g.round_box(Rect2(r.position+Vector2(2,2),r.size-Vector2(4,4)),Color(.2,.4,.4,.5),Color.TRANSPARENT,0,4)
  g.hud_text(str(cannon+1),r.position+Vector2(3,9),7)
  var badge=r.position+Vector2(16,31)
  if selected:
   g.line(badge+Vector2(-4,0),badge+Vector2(-1,3),Color("527c68"),1.7)
   g.line(badge+Vector2(-1,3),badge+Vector2(5,-3),Color("527c68"),1.7)
  elif not unlocked:
   g.draw_arc(badge-Vector2(0,2),2.5,PI,TAU,8,Color("365f60"),1.2,true)
   g.round_box(Rect2(badge-Vector2(3,2),Vector2(6,5)),Color("365f60"),Color.TRANSPARENT,0,1)
  if unlocked and g.state=="play":g.buttons.append({"id":"cannon%d"%cannon,"rect":r})
 g.bar(Vector2(304,347),Vector2(210,3),float(g.xp)/threshold(g),Color("70e4d5"))
 g.text("LV %d"%g.level,Vector2(270,351),8,Color("e8faff"))
 var arms:Array=["cannon"];var abilities:Array=[]
 for id in ranks:
  if id in ARMS:arms.append(id)
  else:abilities.append(id)
 for row in range(2):
  var items=arms if row==0 else abilities
  g.text("ARMS" if row==0 else "BOOST",Vector2(270,313+row*18),7,Color("dff7ff"))
  for i in range(6):
   var pos=Vector2(324+i*34,309+row*18)
   g.round_box(Rect2(pos-Vector2(12,8),Vector2(28,16)),Color(.25,.38,.32,.55),Color(.3,.65,.8,.3),1,4)
   if i>=items.size():continue
   var id=items[i]
   if id=="cannon":icon(g,["cannon","grapeshot","swivel","heavy"][g.weapon],pos,.16)
   else:icon(g,id,pos,.16)
   g.text(str(ranks.get(id,1)),pos+Vector2(8,5),7,Color("f2fbff"))

func projectile_target(g,s:Dictionary,reach:float=170)->Dictionary:
 var best:Dictionary={};var distance=reach
 for e in g.enemies:
  if e in s.get("visited",[]):continue
  var d=s.p.distance_to(e.p)
  if d<distance and g.clear_water_line(s.p,e.p,3):best=e;distance=d
 return best

func draw_bursts(g):
 combos.draw(g,self)
 for path in paths:
  var fade=path.life/.65
  var c=Color("b6a0ed") if path.kind=="pierce" else Color("b99bdb") if path.kind=="shard" else Color("fff0b2")
  g.line(path.a,path.b,Color(c,fade*.55),2 if path.kind!="shard" else 1)
  g.draw_arc(path.b,4+(1-fade)*9,0,TAU,12,Color(c,fade),1.5,true)
  if path.kind=="shell":g.text("BOUNCE %d"%path.count,path.b-Vector2(14,22),8,Color(c,fade))
  elif path.kind=="pierce":g.text("PIERCE %d"%path.count,path.b-Vector2(14,22),8,Color(c,fade))
 for t in traces:
  var u=clampf(1-t.life/.4,0,1);var fade=1-u
  var explosive=t.get("kind","") in ["mine","mortar"]
  var tier=clampi((int(t.get("r",1))-1)/2,0,2)
  var c=(Color("f5be77") if explosive else Color("c5f4df")).lerp(Color("f39c79") if explosive else Color("67dccd"),tier*.22)
  g.draw_arc(t.p,t.radius*(.2+.8*u),0,TAU,36,Color(c,fade*.7),(2.5+tier)*fade+.5,true)
  g.draw_arc(t.p,t.radius*(.1+.6*u),0,TAU,30,Color(.94,1,.88,fade*.35),1,true)
  for i in range(8):
   var dir=Vector2.from_angle(i*TAU/8+.2)
   var p=t.p+dir*t.radius*u-Vector2(0,sin(u*PI)*12)
   if explosive:
    g.material_ellipse(p,Vector2(4,7)*(1-u*.7),Color(c,fade))
    g.line(p,p+dir*7,Color(1,.94,.7,fade),1.4)
   else:
    g.draw_arc(p,3+u*5,0,TAU,16,Color(.85,1,.94,fade),1.5,true)
    g.ellipse(p-Vector2(2,2),Vector2(1.5,1),Color(.97,1,.94,fade))
  if explosive and u<.65:
   for i in range(3):
    var p=t.p+Vector2((i-1)*9,-sin(u*PI)*24)
    g.ellipse(p,Vector2(10,7)*(1+u),Color(.8,.85,.73,fade*.18))
   g.star(t.p,maxf(.9,17*(1-u/.65)),Color("ffdf99"))

func area_scale()->float:return 1+int(ranks.get("blast",0))*.12

func draw_zones(g):
 for z in zones:
  var tier=clampi((int(z.get("r",1))-1)/2,0,2)
  if z.get("flight",0.0)>0:
   var u=clampf(1-z.flight/.65,0,1)
   var ground=z.origin.lerp(z.p,u)
   var p=ground-Vector2(0,sin(u*PI)*42)
   g.soft_shadow(ground,Vector2(6,3),.2)
   for j in range(1,5):
    var v=maxf(0,u-j*.035)
    var tail=z.origin.lerp(z.p,v)-Vector2(0,sin(v*PI)*42)
    g.ellipse(tail,Vector2(3,3)*(1-j*.15),Color(1,.76,.4,.6-j*.1))
   g.material_ellipse(p,Vector2(5,7),Color("e6ac60"))
   g.line(p+Vector2(-2,-7),p+Vector2(2,-7),Color("668f91"),3)
   g.star(p+Vector2(0,-10),2.5,Color("fff0ce"))
   continue
  if z.kind=="mortar":
   var u=clampf(z.time/z.life,0,1)
   for i in range(8):g.draw_arc(z.p,z.radius,i*TAU/8,i*TAU/8+.48,8,Color(1,.76,.42,.65),1.5,true)
   g.draw_arc(z.p,z.radius*(1-u),0,TAU,32,Color(1,.88,.5,.85),1.5,true)
   for side in [-1,1]:g.line(z.p+Vector2(side*8,0),z.p+Vector2(side*15,0),Color("ffdd8a"),2)
   var p=z.origin.lerp(z.p,u)-Vector2(0,sin(u*PI)*65)
   g.soft_shadow(z.origin.lerp(z.p,u),Vector2(7,3),.2)
   var tail=z.origin.lerp(z.p,maxf(0,u-.08))-Vector2(0,sin(maxf(0,u-.08)*PI)*65)
   g.line(tail,p,Color(1,.85,.5,.45),4+tier*2)
   g.material_ellipse(p,Vector2(9,9)*(1+tier*.15),Color("476e9e"))
   if tier>0:g.line(p+Vector2(-6,1),p+Vector2(6,1),Color("edc47c"),2+tier)
   g.draw_arc(p,8,-2.8,-1.2,16,Color("a3cfce"),2,true)
   g.line(p+Vector2(3,-7),p+Vector2(6,-12),Color("c6986e"),1.5)
   g.star(p+Vector2(6,-12),3+sin(phase*25),Color("ffce71"))
  else:oil_fire.draw(g,z,phase)

# Five small outboard stations leave the sail and original cannon readable.
# Stations use hull-plane rotation; their upright toy hardware retains height.
func draw_mounts(g,angle:float,front:bool):
 var equipped:Array=[]
 for id in ranks:
  if id in ARMS and int(ranks[id])>0:equipped.append(id)
 var stations=[Vector2(17,-14),Vector2(17,14),Vector2(-1,-18),Vector2(-1,18),Vector2(-21,0)]
 for i in range(mini(5,equipped.size())):
  var id:String=equipped[i]
  var local:Vector2=stations[i].rotated(angle)
  if (local.y>=0)!=front:continue
  var p=Vector2(local.x,local.y*.62-6)
  var c:Color=INFO[id][2]
  g.material_ellipse(p+Vector2(0,3),Vector2(6.5,3.2),Color("668f91"))
  g.material_ellipse(p+Vector2(0,1),Vector2(5.8,2.5),Color("fff0ce"))
  match id:
   "bubble":
    g.material_ellipse(p+Vector2(0,-4),Vector2(5,6),c)
    g.draw_arc(p+Vector2(0,-4),3.5,-2.8,-1.3,10,Color("fff0ce"),1.2,true)
    g.material_ellipse(p+Vector2(4,-1),Vector2(2.7,2.2),Color("668f91"))
   "mine":
    g.line(p+Vector2(-5,0),p+Vector2(5,0),Color("668f91"),2)
    for x in [-2.8,2.8]:
     g.material_ellipse(p+Vector2(x,-3),Vector2(3,3.4),Color("718f9c"))
     g.ellipse(p+Vector2(x,-6),Vector2(1.2,1.2),Color("f9bd6c"))
   "battery":
    g.line(p,p+Vector2(-3,-8),c,7)
    g.material_ellipse(p+Vector2(-3,-8),Vector2(4,2.6),Color("426776"))
    g.ellipse(p+Vector2(-3,-8),Vector2(2.2,1.3),Color("263f50"))
   "shell":
    g.material_ellipse(p+Vector2(0,-4),Vector2(6,5),c)
    for k in range(5):g.line(p+Vector2(0,0),p+Vector2.from_angle(-PI*.9+k*PI*.2)*5+Vector2(0,-3),Color("fff0ce"),.8)
   "starfish":
    g.material_ellipse(p,Vector2(5,2.5),Color("668f91"))
    g.star(p+Vector2(0,-5),6,c)
    g.ellipse(p+Vector2(0,-5),Vector2(1.5,1.5),Color("fff0ce"))
   "flare":
    g.draw_arc(p+Vector2(0,-7),3,PI,TAU,10,Color("668f91"),1.4,true)
    g.material_ellipse(p+Vector2(0,-4),Vector2(4,5),Color("f9bd6c"))
    g.material_ellipse(p+Vector2(0,-4),Vector2(2,3),Color("fff0ce"))
    g.line(p+Vector2(-4,-8),p+Vector2(4,-8),c,2)
   "escort":
    g.material_ellipse(p+Vector2(0,-2),Vector2(6,3),c)
    g.line(p+Vector2(0,-2),p+Vector2(0,-11),Color("668f91"),1.4)
    g.smooth_polygon(PackedVector2Array([p+Vector2(1,-11),p+Vector2(6,-6),p+Vector2(1,-6)]),Color("fff0ce"))

func add_path(a:Vector2,b:Vector2,kind:String,count:int):
 # Small bounded list: hit-to-hit trajectories, not per-frame particles.
 if paths.size()>=24:paths.pop_front()
 paths.append({"a":a,"b":b,"kind":kind,"count":count,"life":.65})
