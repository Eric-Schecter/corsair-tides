extends RefCounted
# Unlocks live outside equipment ranks: combinations never consume a slot.
const RECIPES={
 "steam":["Boiling bubbles","Bubbles touch oil: steam blast + 3s vulnerability.",["bubble","flare"],Color("9cddd1")],
 "firechain":["Burning minefield","Mines leave fire and ignite nearby armed mines.",["mine","flare"],Color("efb477")],
 "shards":["Shell storm","Starfish hits release 3 bouncing shell fragments.",["starfish","shell"],Color("d7b5d7")]}
var unlocked:Dictionary={}
var effects:Array=[]
var pending_shots:Array=[]
var proc_counts:Dictionary={}
var pulses:Dictionary={}
var links:Array=[]

func reset():
 unlocked.clear();effects.clear();pending_shots.clear();proc_counts.clear();pulses.clear();links.clear()

func eligible(ranks:Dictionary)->Array:
 var result:Array=[]
 for id in RECIPES:
  if unlocked.has(id):continue
  var pair=RECIPES[id][2]
  if ranks.has(pair[0]) and ranks.has(pair[1]):result.append(id)
 return result

func tick(dt:float):
 for id in pulses:pulses[id]=maxf(0,pulses[id]-dt)
 for link in links:link.life-=dt
 links=links.filter(func(link):return link.life>0)
 for fx in effects:fx.age+=dt
 effects=effects.filter(func(fx):return fx.age<fx.duration)

func effect(id:String,p:Vector2,radius:float):
 if effects.size()>=32:effects.pop_front()
 effects.append({"id":id,"p":p,"radius":radius,"age":0.0,"duration":.85 if id=="steam" else .6})
 proc_counts[id]=int(proc_counts.get(id,0))+1
 pulses[id]=.85

func steam(g,u,s:Dictionary)->bool:
 if not unlocked.has("steam"):return false
 var in_fire=false
 for z in u.zones:
  if z.kind=="oil" and z.get("flight",0.0)<=0 and z.time<z.life and s.p.distance_to(z.p)<z.radius:
   in_fire=true;break
 if not in_fire:return false
 s.life=0
 var radius=(60+s.r*5)*u.area_scale()
 for e in g.enemies.duplicate():
  if e.p.distance_to(s.p)>radius or not g.clear_water_line(s.p,e.p,3):continue
  # Refresh duration, never stack the multiplier.
  e["steam_until"]=u.phase+3.0
  var index=g.enemies.find(e)
  if index>=0:g.damage_enemy(index,s.damage*1.4,(e.p-s.p).normalized()*60)
 effect("steam",s.p,radius);g.sfx("combo_steam")
 return true

func ignite(g,u,s:Dictionary):
 if not unlocked.has("firechain"):return
 var radius=65*u.area_scale()
 if u.zones.size()<32:
  u.zones.append({"kind":"oil","r":s.get("r",1),"p":s.p,"origin":s.p,"time":0.0,"life":3.0,"radius":radius*.72,"damage":s.damage*.18,"pulse":.2})
 for other in u.shots:
  if other==s or other.kind!="mine" or other.life<=0 or other.life>7.4:continue
  if other.has("chain_fuse"):continue
  if other.p.distance_to(s.p)<=radius and g.clear_water_line(s.p,other.p,3):
   other["chain_fuse"]=.24
   if links.size()>=16:links.pop_front()
   links.append({"a":s.p,"b":other.p,"life":.5})
 effect("firechain",s.p,radius);g.sfx("combo_chain")

func fragment(g,u,s:Dictionary,victim:Dictionary):
 if not unlocked.has("shards") or float(s.get("shard_cd",0))>0:return
 s["shard_cd"]=.35
 var targets:Array=[]
 for e in g.enemies:
  if e==victim or e.p.distance_to(s.p)>130 or not g.clear_water_line(s.p,e.p,3):continue
  targets.append(e)
 for i in range(3):
  if u.shots.size()+pending_shots.size()>=96:break
  var dir=Vector2.from_angle(i*TAU/3)
  if not targets.is_empty():dir=(targets[i%targets.size()].p-s.p).normalized().rotated((i-1)*.18)
  pending_shots.append({"kind":"shell","fragment":true,"last_hit":s.p,"bounces":0,"p":s.p,"v":dir*260,"life":.9,"damage":s.damage*.4,"r":1,"left":2,"visited":[victim]})
 effect("shards",s.p,26);g.sfx("combo_shards")

func illustration(g,u,id:String,p:Vector2,size:float=1):
 var pair=RECIPES[id][2];var tint:Color=RECIPES[id][3]
 g.draw_arc(p,35*size,0,TAU,40,Color(tint,.65),3*size,true)
 u.icon(g,pair[0],p+Vector2(-17,2)*size,.75*size)
 u.icon(g,pair[1],p+Vector2(18,6)*size,.62*size)
 if id=="steam":
  for i in range(3):g.material_ellipse(p+Vector2((i-1)*10,-23-i%2*5)*size,Vector2(8,6)*size,Color("f7f2d9"))
 elif id=="firechain":
  g.star(p+Vector2(0,-27)*size,9*size,Color("ffe49d"))
 else:
  for i in range(3):u.icon(g,"shell",p+Vector2.from_angle(i*TAU/3)*37*size,.2*size)

func draw(g,u):
 for link in links:
  var progress=clampf((.5-link.life)/.24,0,1)
  g.line(link.a,link.b,Color(1,.65,.35,.35),1.5)
  g.star(link.a.lerp(link.b,progress),4,Color("ffe49d"))
 for fx in effects:
  var t=fx.age/fx.duration;var fade=1-t;var p:Vector2=fx.p
  var tint:Color=RECIPES[fx.id][3]
  if fx.id!="firechain":g.draw_arc(p,fx.radius*(.3+t*.7),0,TAU,40,Color(tint,fade*.8),2,true)
  if fx.id=="steam":
   for i in range(7):
    var cloud=p+Vector2.from_angle(i*2.399)*fx.radius*.45*t-Vector2(0,t*28)
    g.ellipse(cloud,Vector2(10,7)*(1+t),Color(.94,.98,.87,fade*.38))
   for i in range(4):g.draw_arc(p+Vector2.from_angle(i*TAU/4)*fx.radius*t,4+t*5,0,TAU,16,Color(.85,1,.94,fade),1,true)
  elif fx.id=="firechain":
   for i in range(8):
    var dir=Vector2.from_angle(i*TAU/8)
    g.line(p+dir*fx.radius*t*.6,p+dir*fx.radius*t,Color(1,.65,.35,fade),2)
    g.star(p+dir*fx.radius*t,3*fade,Color("ffe498"))
  else:
   for i in range(6):
    var pos=p+Vector2.from_angle(i*TAU/6)*fx.radius*t
    g.star(pos,4*fade,tint)
 for e in g.enemies:
  if float(e.get("steam_until",0))<=u.phase:continue
  g.draw_arc(e.p,20,0,TAU,24,Color(.9,.98,.8,.55),1,true)
  g.smooth_polygon(PackedVector2Array([e.p+Vector2(-4,-35),e.p+Vector2(4,-35),e.p+Vector2(0,-29)]),Color("b38fe0"))

func hud(g,u):
 var i=0
 for id in unlocked:
  var p=Vector2(455,282+i*18)
  var active=float(pulses.get(id,0))>0
  g.round_box(Rect2(p-Vector2(8,7),Vector2(110,15)),Color("ffe0a1") if active else Color("fff0ce"),RECIPES[id][3],2 if active else 1,4)
  if active:
   var label={"steam":"STEAM: +25% DAMAGE","firechain":"CHAIN DETONATION","shards":"3 RICOCHET SHARDS"}[id]
   g.hud_text(label,Vector2(244,90+i*12),8)
  g.star(p,5,RECIPES[id][3])
  g.hud_text({"steam":"STEAM","firechain":"FIRE CHAIN","shards":"SHARDS"}[id]+" x%d"%int(proc_counts.get(id,0)),p+Vector2(10,4),7)
  i+=1
