extends Node2D

var sea_color:Color
var polygons:Array=[]

func configure(layers:Array,sea:Color):
 sea_color=sea
 polygons.clear()
 for layer in layers:
  var points:PackedVector2Array=layer.points
  var bounds=Rect2(points[0],Vector2.ZERO)
  for point in points:bounds=bounds.expand(point)
  var colors=PackedColorArray()
  for point in points:
   var color:Color=layer.color
   if color.a>=.99:
    var uv=(point-bounds.get_center())/(bounds.size*.5)
    var shade=uv.dot(Vector2(-.6,-.8))*.11
    color=color.lerp(Color("d4f7de"),shade) if shade>0 else color.lerp(Color("5b927e"),-shade)
   colors.append(color)
  polygons.append({"points":points,"colors":colors})
 queue_redraw()

func _draw():
 draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(1900,0),Vector2(1900,1900),Vector2(0,1900)]),PackedColorArray([sea_color.lerp(Color("29bfc3"),.38),sea_color,sea_color.lerp(Color("77e9d0"),.45),sea_color]))
 # Broad, soft currents echo t5's painted turquoise water; cached with terrain.
 for band in range(10):
  var strip=PackedVector2Array()
  for i in range(40):
   var x=i*1900.0/39
   strip.append(Vector2(x,band*210+sin(x/155+band*1.7)*20))
  for i in range(39,-1,-1):
   var x=i*1900.0/39
   strip.append(Vector2(x,band*210+sin(x/155+band*1.7+.2)*20+18))
  draw_colored_polygon(strip,Color(.60,1,.85,.10))
 for polygon in polygons:draw_polygon(polygon.points,polygon.colors)
