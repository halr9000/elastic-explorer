class_name EEAudio
extends Node
var _master: float = 0.75
var _effects: float = 0.8
var _ambience: float = 0.35
var _voices: Array[AudioStreamPlayer] = []
var _bed: AudioStreamPlayer
var _slap: AudioStreamWAV
var _pickup: AudioStreamWAV
var _jump: AudioStreamWAV

func _ready() -> void:
	_slap = _synthesize(0.23, "slap")
	_pickup = _synthesize(0.42, "pickup")
	_jump = _synthesize(0.15, "jump")
	for i in 8:
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_bed = AudioStreamPlayer.new()
	add_child(_bed)
	_bed.stream = _synthesize(4.0,"bed")
	_bed.play()
	set_levels(_master, _effects, _ambience)

func _synthesize(duration: float, kind: String) -> AudioStreamWAV:
	var rate = 22050
	var count = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 829
	for i in count:
		var t = float(i) / rate
		var p = t / duration
		var value: float
		if kind == "slap": value = (rng.randf_range(-1,1)*0.55*exp(-t*40)+sin(TAU*(95*t-100*t*t))*0.65*exp(-t*20))*minf(t*900,1)
		elif kind == "pickup": value = (sin(TAU*660*t)+sin(TAU*990*t)*0.4)*0.32*sin(PI*p)*exp(-p*3)
		elif kind == "jump": value = sin(TAU*(140*t+600*t*t))*0.35*sin(PI*p)
		else: value = (sin(TAU*55*t)*0.08+sin(TAU*82.5*t)*0.04+sin(TAU*110*t)*0.025)*(0.8+0.2*sin(TAU*t/4))
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if kind == "bed":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func set_levels(master: float, effects: float, ambience: float) -> void:
	_master = clampf(master,0,1)
	_effects = clampf(effects,0,1)
	_ambience = clampf(ambience,0,1)
	for voice in _voices: voice.volume_db = linear_to_db(maxf(0.00001,_master*_effects))
	if is_instance_valid(_bed): _bed.volume_db = linear_to_db(maxf(0.00001,_master*_ambience))

func _play(stream: AudioStreamWAV) -> void:
	for voice in _voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			return

func play_slap() -> void: _play(_slap)
func play_pickup() -> void: _play(_pickup)
func play_jump() -> void: _play(_jump)

func stop_all() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(_bed):
		_bed.stop()
		_bed.stream = null

func _exit_tree() -> void:
	stop_all()
