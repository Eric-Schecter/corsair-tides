extends AudioStreamPlayer

var gain=0.0

func _ready():
 var music:AudioStreamWAV=load("res://assets/audio/harbor-bgm.wav")
 music=music.duplicate()
 music.loop_mode=AudioStreamWAV.LOOP_FORWARD
 music.loop_begin=0
 music.loop_end=int(music.get_length()*music.mix_rate)
 stream=music
 volume_db=-80
 play()

func update_mix(state:String,muted:bool,testing:bool,dt:float):
 # The music has its own player and never steals combat SFX voices.
 var should_pause=muted or testing
 if stream_paused!=should_pause:stream_paused=should_pause
 var target=.15 if state=="play" else .10 if state in ["pause","upgrade"] else .18
 if stream_paused:target=0
 gain=move_toward(gain,target,dt*.25)
 volume_db=linear_to_db(maxf(.0001,gain))
