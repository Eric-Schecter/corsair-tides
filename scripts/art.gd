extends RefCounted
class_name ZArt

static var rng=RandomNumberGenerator.new()
static var cached_worlds:Dictionary={}
const HULLS=[Color("ed826f"),Color("df92a0"),Color("79b9a6"),Color("b3a2ca"),Color("73afbd"),Color("e6aa6d")]
const SAILS=[Color("fff0ce"),Color("f9e5d1"),Color("e9edd0"),Color("f0e5dc"),Color("e6efdb"),Color("fae6bb")]



static func box(im:Image,x:float,y:float,w:float,h:float,c:Color):
 var r=Rect2i(int(x),int(y),maxi(1,int(w)),maxi(1,int(h))).intersection(Rect2i(0,0,im.get_width(),im.get_height()))
 if r.has_area():im.fill_rect(r,c)

static func oval(im:Image,x:int,y:int,w:int,h:int,c:Color):
 for yy in range(maxi(0,y),mini(im.get_height(),y+h)):
  for xx in range(maxi(0,x),mini(im.get_width(),x+w)):
   if pow((xx-x-w*.5)/(w*.5),2)+pow((yy-y-h*.5)/(h*.5),2)<1:im.set_pixel(xx,yy,c)

static func poly(im:Image,points:PackedVector2Array,c:Color):
 var bounds=Rect2(points[0],Vector2.ZERO)
 for p in points:bounds=bounds.expand(p)
 for y in range(maxi(0,int(bounds.position.y)),mini(im.get_height(),ceili(bounds.end.y)+1)):
  for x in range(maxi(0,int(bounds.position.x)),mini(im.get_width(),ceili(bounds.end.x)+1)):
   if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),points):im.set_pixel(x,y,c)

static func island_shape(center:Vector2,radii:Vector2,seedn:int,scale_factor:float=1.0)->PackedVector2Array:
 var pts=PackedVector2Array()
 for i in range(96):
  var a=i*TAU/96
  var f=1+.045*sin(a*3+seedn)+.025*sin(a*5+seedn*.31)
  pts.append(center+Vector2(cos(a),sin(a))*radii*f*scale_factor)
 return pts

# Rasterize only the small chart; live terrain uses the unchanged world polygons.
static func map_poly(im:Image,points:PackedVector2Array,c:Color):
 var scaled=PackedVector2Array()
 for p in points:scaled.append(p*(176.0/1900.0))
 poly(im,scaled,c)

static func map_box(_im:Image,_x:float,_y:float,_w:float,_h:float,_c:Color):
 pass # Subpixel decoration is rendered by the live scene, not the chart.

static func map_oval(_im:Image,_x:int,_y:int,_w:int,_h:int,_c:Color):
 pass

static func world(map_id:int)->Dictionary:
 if cached_worlds.has(map_id):return cached_worlds[map_id]
 rng.seed=810+map_id*51
 var im=Image.create(176,176,false,Image.FORMAT_RGBA8)
 var deep=[Color("2dc9c8"),Color("31bfc8"),Color("36cfbf")][map_id]
 var shelf=[Color("57dbcf"),Color("60d9d7"),Color("67decb")][map_id]
 var shoal=[Color("9be9ce"),Color("a2e7d7"),Color("ace9ce")][map_id]
 var sand=[Color("f3dfb1"),Color("eedbb2"),Color("f2dbb2")][map_id]
 var grass=[Color("9dce69"),Color("87c780"),Color("b0d16c")][map_id]
 var islands:Array=[]
 if map_id==0:
  islands=[ [Vector2(170,1000),Vector2(224,184)], [Vector2(1040,960),Vector2(155,138)], [Vector2(330,460),Vector2(214,149)], [Vector2(1430,150),Vector2(150,132)], [Vector2(1470,560),Vector2(186,174)], [Vector2(690,1500),Vector2(183,145)], [Vector2(220,1600),Vector2(104,145)], [Vector2(1510,1470),Vector2(243,205)], [Vector2(900,530),Vector2(86,67)] ]
 elif map_id==1:
  islands=[ [Vector2(150,1000),Vector2(240,163)], [Vector2(920,850),Vector2(142,225)], [Vector2(300,410),Vector2(240,118)], [Vector2(1460,150),Vector2(152,128)], [Vector2(1460,710),Vector2(190,107)], [Vector2(1140,1410),Vector2(260,151)], [Vector2(360,1580),Vector2(161,182)], [Vector2(1650,1670),Vector2(124,130)], [Vector2(850,280),Vector2(65,111)] ]
 else:
  islands=[ [Vector2(175,1000),Vector2(227,168)], [Vector2(1050,1000),Vector2(172,151)], [Vector2(380,480),Vector2(206,154)], [Vector2(1460,150),Vector2(150,130)], [Vector2(1460,660),Vector2(130,238)], [Vector2(710,1520),Vector2(264,172)], [Vector2(1500,1480),Vector2(214,188)], [Vector2(950,410),Vector2(89,63)] ]
 im.fill(deep)
 # Broad, broken currents are baked beneath fine moving wavelets.
 for i in range(700):
  var p=Vector2(rng.randi_range(0,1899),rng.randi_range(0,1899))
  map_oval(im,int(p.x),int(p.y),rng.randi_range(45,180),rng.randi_range(12,44),deep.lightened(rng.randf_range(.005,.025)))
 var layers:Array=[]
 var land:Array=[];var obstacles:Array[Rect2]=[];var palms:Array=[];var rocks:Array=[]
 for n in range(islands.size()):
  var p:Vector2=islands[n][0];var r:Vector2=islands[n][1];var seedn=n*13+map_id*31
  map_poly(im,island_shape(p,r,seedn,1.37),deep.lerp(shelf,.45))
  map_poly(im,island_shape(p,r,seedn,1.24),shelf)
  map_poly(im,island_shape(p,r,seedn,1.13),shoal)
  map_poly(im,island_shape(p,r,seedn,1.04),sand.darkened(.13))
  map_poly(im,island_shape(p,r,seedn,.98),sand)
  map_poly(im,island_shape(p+Vector2(-1,-4),r,seedn,.84),grass.darkened(.24))
  map_poly(im,island_shape(p+Vector2(-3,-9),r,seedn,.8),grass)
  for layer in [[p,r,1.22,shelf],[p,r,1.095,shoal],[p+Vector2(5,7),r,1.035,Color(.08,.26,.25,.08)],[p+Vector2(3,5),r,1.025,Color(.08,.26,.25,.10)],[p+Vector2(0,7),r,1.025,sand.darkened(.24)],[p,r,1.015,sand],[p+Vector2(7,8),r,.86,Color(.19,.28,.16,.08)],[p+Vector2(5,6),r,.85,Color(.19,.28,.16,.10)],[p+Vector2(2,8),r,.84,grass.darkened(.25)],[p+Vector2(-3,-9),r,.82,grass]]:
   layers.append({"points":island_shape(layer[0],layer[1],seedn,layer[2]),"color":layer[3]})
  land.append(island_shape(p,r,seedn,1.015));obstacles.append(Rect2(p-r*1.15,r*2.3))
  for i in range(2200):
   var a=rng.randf()*TAU;var rad=sqrt(rng.randf())
   var v=p+Vector2(cos(a),sin(a))*r*rad
   if v.x<0 or v.y<0 or v.x>=1900 or v.y>=1900:continue
   var c=im.get_pixel(int(v.x*176/1900),int(v.y*176/1900))
   if c.r>.2:
    var tint=c.lightened(.035) if i%3 else c.darkened(.07)
    map_box(im,v.x,v.y,rng.randi_range(1,4),rng.randi_range(1,3),tint)
  for i in range(14):
   var a=rng.randf()*TAU
   var v=p+Vector2(cos(a),sin(a))*r*rng.randf_range(.87,.94)
   var star=PackedVector2Array()
   for j in range(10):
    var angle=j*TAU/10-PI/2
    star.append(v+Vector2.from_angle(angle)*(4.0 if j%2==0 else 1.8))
   map_poly(im,star,Color("e9ad8c"))
  for i in range(24):
   var a=rng.randf()*TAU
   var v=p+Vector2(cos(a),sin(a))*r*rng.randf_range(.18,.72)
   var petal=[Color("ffe7ad"),Color("f5b9c1"),Color("e6e1ff")][i%3]
   map_oval(im,int(v.x)-2,int(v.y)-1,5,3,petal);map_oval(im,int(v.x)-1,int(v.y)-2,3,5,petal)
   map_box(im,v.x,v.y,1,1,Color("e7ba72"))
  for i in range(36):
   var a=rng.randf()*TAU;var v=p+Vector2.from_angle(a)*r*rng.randf_range(.65,.98)
   if i%2==0:
    var rr=rng.randi_range(3,8);map_oval(im,int(v.x),int(v.y),rr+3,rr,Color("aab8b1"));map_box(im,v.x+2,v.y+1,rr-1,2,Color("d4d8c2"))
   elif map_id!=1:palms.append({"p":p+Vector2.from_angle(a)*r*rng.randf_range(.18,.66),"seed":rng.randi(),"type":"palm"})
  for i in range(1000):
   var a=rng.randf()*TAU;var v=p+Vector2(cos(a),sin(a))*r*rng.randf_range(.96,1.37)
   if v.x<0 or v.y<0 or v.x>=1900 or v.y>=1900:continue
   var c=im.get_pixel(int(v.x*176/1900),int(v.y*176/1900))
   if c.r<.65:
    map_box(im,v.x,v.y,rng.randi_range(1,5),1,c.lightened(.025) if i%3 else c.darkened(.035))
  for i in range(40):
   var a=rng.randf()*TAU;var v=p+Vector2(cos(a),sin(a))*r*rng.randf_range(1.02,1.18)
   map_box(im,v.x,v.y,3,1,shoal.darkened(.09))
  # Sparse edge flecks break the waterline instead of tracing a uniform foam ring.
  var coast=island_shape(p,r,seedn,1.075)
  for i in range(0,64,3):
   var v=coast[i]
   map_box(im,v.x,v.y,rng.randi_range(2,8),1,shoal.lightened(.10))
   if i%2:map_box(im,v.x+3,v.y+3,3,1,sand.lerp(shoal,.5))
  if map_id==1:
   for i in range(11):
    var v=p+Vector2(rng.randf_range(-.55,.55),rng.randf_range(-.55,.55))*r
    rocks.append({"p":v,"type":"rock","seed":rng.randi()})
 # The port is rooted in the western island; the berth remains navigable.
 for i in range(8000):
  var x=rng.randi_range(0,1899);var y=rng.randi_range(0,1899);var c=im.get_pixel(int(x*176.0/1900),int(y*176.0/1900))
  if c.r<.45:map_box(im,x,y,rng.randi_range(1,5),1,c.lightened(rng.randf_range(.004,.018)))
 var strokes:Array=[]
 for i in range(1500):
  var p=Vector2(rng.randi_range(5,1890),rng.randi_range(5,1890))
  var clear=true
  for k in range(land.size()):
   if obstacles[k].has_point(p) and Geometry2D.is_point_in_polygon(p,land[k]):clear=false;break
  if clear:strokes.append({"p":p,"phase":rng.randf()*TAU,"width":rng.randi_range(3,12)})
 im.resize(88,88,Image.INTERPOLATE_LANCZOS)
 cached_worlds[map_id]={"image":im,"layers":layers,"deep":deep,"obstacles":obstacles,"land":land,"palms":palms,"rocks":rocks,"waves":strokes}
 return cached_worlds[map_id]

static func hull(job:int,enemy:bool=false)->ImageTexture:
 var im=Image.create(80,64,false,Image.FORMAT_RGBA8)
 var paint=HULLS[job%6] if not enemy else Color("864c99")
 # A wide little bathtub hull, with a cream gunwale and simple toy-like fittings.
 oval(im,17,14,49,36,Color("547b86"))
 oval(im,18,14,47,33,paint.darkened(.12))
 oval(im,20,14,43,30,Color("cb9e59"))
 oval(im,23,17,37,24,Color("c78d53"))
 for y in [22,28,34]:box(im,26,y,29,1,Color("9f673e"))
 box(im,22,20,7,17,paint);box(im,23,20,5,2,paint.lightened(.25))
 oval(im,25,24,4,8,Color("dfc18c"))
 for x in [34,47]:
  oval(im,x,26,7,10,Color("c29a6d"));box(im,x+1,27,5,7,Color("f1d099"))
 for x in [30,44,55]:
  for y in [14,39]:
   oval(im,x,y,5,7,Color("648a95"));box(im,x+1,y+1,2,2,Color("a6c6c4"))
 # Pale bumpers, a short bowsprit and a little life belt on the stern.
 oval(im,17,24,7,12,Color("e6cca0"));oval(im,19,27,3,6,paint)
 box(im,61,28,7,3,Color("d6ac7b"))
 box(im,26,17,23,1,Color("e8b967"))
 for y in [20,38]:oval(im,23,y,3,3,Color("ffda8b"))
 return ImageTexture.create_from_image(im)

static func ship_thumb(job:int)->ImageTexture:
 var im=hull(job).get_image()
 for x in ([38] if job==3 else ([27,40,52] if job==4 else [29,47])):
  oval(im,x-1,10,14,43,SAILS[job].darkened(.12))
  oval(im,x,10,12,40,SAILS[job])
  box(im,x+2,13,2,32,SAILS[job].lightened(.2))
  box(im,x-1,12,1,39,Color("af8d6e"))
  if x>35:
   oval(im,x+7,24,2,3,Color("436777"));oval(im,x+7,34,2,3,Color("436777"))
   box(im,x+10,29,1,3,Color("d78681"))
 return ImageTexture.create_from_image(im)
