extends Node

# Procedural sound effects. No audio files: each sound is synthesized once at startup.

const RATE := 22050

const SINE := 0
const SQUARE := 1
const NOISE := 2

var _claim: AudioStreamPlayer
var _crash: AudioStreamPlayer
var _level: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _explode: AudioStreamPlayer


func _ready() -> void:
	# Rising chime: area claimed.
	_claim = _player(_synth([_seg(523, 1046, 0.25, SINE, 0.5)]))
	# Falling square tone then crackle: crash.
	_crash = _player(_synth([_seg(320, 60, 0.4, SQUARE, 0.45), _seg(0, 0, 0.25, NOISE, 0.4)]))
	# Four-note arpeggio: level passed.
	_level = _player(_synth([
		_seg(523, 523, 0.12, SQUARE, 0.3),
		_seg(659, 659, 0.12, SQUARE, 0.3),
		_seg(784, 784, 0.12, SQUARE, 0.3),
		_seg(1046, 1046, 0.4, SQUARE, 0.3),
	]))
	# Low sustained tone, looped while a cut is being drawn.
	_hum = _player(_synth([_seg(200, 200, 0.5, SINE, 0.12, false)], true))
	# Short noise burst with a falling tone: enemy destroyed.
	_explode = _player(_synth([_seg(0, 0, 0.2, NOISE, 0.45), _seg(260, 50, 0.3, SINE, 0.3)]))


func _exit_tree() -> void:
	for p in get_children():
		p.stop()


func claim() -> void:
	_claim.play()


func explode() -> void:
	_explode.play()


func crash() -> void:
	_crash.play()


func level_passed() -> void:
	_level.play()


func draw_start() -> void:
	if not _hum.playing:
		_hum.play()


func draw_stop() -> void:
	_hum.stop()


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _seg(f0: float, f1: float, dur: float, wave: int, vol: float, decay := true) -> Dictionary:
	return {"f0": f0, "f1": f1, "dur": dur, "wave": wave, "vol": vol, "decay": decay}


func _synth(segs: Array, loop := false) -> AudioStreamWAV:
	var total := 0
	for seg in segs:
		total += int(seg.dur * RATE)
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var idx := 0
	var phase := 0.0
	for seg in segs:
		var n := int(seg.dur * RATE)
		for i in n:
			var t := float(i) / RATE
			var f: float = lerpf(seg.f0, seg.f1, t / seg.dur)
			phase += TAU * f / RATE
			var v := 0.0
			match seg.wave:
				SINE:
					v = sin(phase)
				SQUARE:
					v = 1.0 if sin(phase) >= 0.0 else -1.0
				_:
					v = randf() * 2.0 - 1.0
			var env: float = (1.0 - t / seg.dur) if seg.decay else 1.0
			var attack := minf(1.0, t / 0.005)
			var sample := clampf(v * seg.vol * env * attack, -1.0, 1.0)
			pcm.encode_s16(idx * 2, int(sample * 32767.0))
			idx += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = total
	return stream
