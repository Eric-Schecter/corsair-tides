extends RefCounted
# Small shared animation sheet: layered toy flames without per-frame tessellation.
var legacy=OS.get_cmdline_user_args().has("--perf-old-fire")
var texture:ImageTexture
var anchors:Array[Vector2]=[]

func _init():
 for i in range(9):anchors.append(Vector2.from_angle(i*2.399)*sqrt(i/9.0)*.78)
 anchors.sort_custom(func(a,b):return a.y<b.y)
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="3072"><defs><linearGradient id="outer" x1="0" y1="1" x2="0" y2="0"><stop stop-color="#db5949"/><stop offset="1" stop-color="#ffad44"/></linearGradient><linearGradient id="inner" x1="0" y1="1" x2="0" y2="0"><stop stop-color="#ff9c36"/><stop offset="1" stop-color="#ffda69"/></linearGradient></defs>'
 for tier in range(3):
  for frame in range(32):
   svg+='<g transform="translate(%d %d) scale(2)">'%[(frame%8)*256,(tier*4+frame/8)*256]
   for i in range(anchors.size()):
    var t=frame*TAU/32.0+i*.71
    var lean=sin(t)*3.0
    var tip=5+sin(t*2)*2.0
    var h=(25+sin(t*2)*3+float(i%3)*3)*(1+tier*.18)
    var scale=h/48.0
    var p=Vector2(64,82)+anchors[i]*48
    svg+='<g transform="translate(%.2f %.2f) scale(%.3f)">'%[p.x-16*scale,p.y-44*scale,scale]
    svg+='<path d="M16 44 C3 45 2 35 7 26 C8 32 11 32 11 25 C10 17 17 15 %.2f %.2f C25 16 19 22 24 26 C26 28 27 24 27 22 C34 35 28 44 16 44Z" fill="url(#outer)" stroke="#d86548" stroke-width="0.6"/>'%[17+lean,tip]
    svg+='<path d="M16 42 C8 41 7 34 12 28 C13 32 15 29 %.2f 19 C23 27 19 29 23 32 C28 39 22 43 16 42Z" fill="url(#inner)"/>'%[18+lean*.6]
    svg+='<path d="M16 41 C11 40 12 36 15 33 C16 35 18 32 18 29 C24 35 22 42 16 41Z" fill="#ffe797"/>'
    svg+='<ellipse cx="13" cy="39" rx="2" ry="1" fill="#fff0b5" opacity="0.65"/></g>'
   svg+='</g>'
 svg+='</svg>'
 var img=Image.new()
 if img.load_svg_from_string(svg)==OK:texture=ImageTexture.create_from_image(img)

func draw(g,z:Dictionary,phase:float):
 if legacy:draw_legacy(g,z,phase);return
 if texture==null:return
 var fade=minf(1,z.time/.2)*clampf((z.life-z.time)/.45,0,1)
 var r:float=z.radius
 # Warm reflected light is confined to the oil patch, never a screen-wide bloom.
 g.ellipse(z.p,Vector2(r,r*.65),Color(.30,.20,.27,.22*fade))
 g.ellipse(z.p+Vector2(0,3),Vector2(r*.88,r*.48),Color(1,.43,.20,.12*fade))
 var tier=clampi((int(z.get("r",1))-1)/2,0,2)
 var frame=int(fposmod(phase*(3.0+tier*.25)+z.p.x*.013,TAU)/TAU*32)
 var scale=r/48.0
 g.draw_texture_rect_region(texture,Rect2(z.p-Vector2(64,82)*scale,Vector2(128,128)*scale),Rect2((frame%8)*256,(tier*4+frame/8)*256,256,256),Color(1,1,1,fade))
 for i in range(5):
  var rise=fposmod(phase*.7+i*.23,1.0)
  var p:Vector2=z.p+anchors[i*2]*r*.7+Vector2(sin(phase*2+i)*4,-12-rise*36)
  g.ellipse(p,Vector2(1,1.7)*(1-rise*.6),Color(1,.78,.35,(1-rise)*fade*.8))
 for i in range(2):
  var rise=fposmod(phase*.33+i*.5,1.0)
  var p:Vector2=z.p+Vector2((i*2-1)*r*.3+sin(phase+i)*5,-20-rise*30)
  g.ellipse(p,Vector2(7,5)*(1+rise),Color(.40,.37,.43,(1-rise)*fade*.10))

# Diagnostic A/B reference; normal gameplay always uses the shared atlas.
func draw_legacy(g,z:Dictionary,phase:float):
 g.ellipse(z.p,Vector2(z.radius,z.radius*.65),Color(.22,.22,.35,.3))
 g.draw_arc(z.p,z.radius,0,TAU,32,Color(1,.57,.3,.3),1,true)
 for i in range(9):
  var p=z.p+Vector2.from_angle(i*2.399)*sqrt(i/9.0)*z.radius*.8
  var h=10+sin(phase*9+i)*4
  var flame=PackedVector2Array()
  for j in range(13):
   var u=j/12.0;var bend=sin(phase*5+i)*4*u*u
   flame.append(p+Vector2(bend-sin(u*PI)*6,-u*h*2))
  for j in range(11,0,-1):
   var u=j/12.0;var bend=sin(phase*5+i)*4*u*u
   flame.append(p+Vector2(bend+sin(u*PI)*6,-u*h*2))
  g.smooth_polygon(flame,Color("ee9973"))
  g.material_ellipse(p-Vector2(0,h*.55),Vector2(2.5,h*.65),Color("ffe5a6"))
  g.draw_circle(p+Vector2(sin(i+phase)*5,-fmod(phase*17+i*5,35)),1.2,Color(1,.88,.55,.65))
