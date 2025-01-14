extends Node

var map = "res://Main.tscn"
var player = "res://Instances/Player-VR.tscn"
var spawn = null
var mute = false
var vr_left_handed = false
var vr_smooth_turn = false
var vr_seated_mode = false

func _physics_process(delta):
#	if Input.is_action_just_pressed("mute"):
#		mute = !mute
#		AudioServer.set_bus_mute(0, mute)
	pass
	
func _ready():
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_network_peer_disconnected")

func create_server():
	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_server(4242, 2)
	print(err)
	get_tree().set_network_peer(peer)

	load_game()

func join_server(ip):
	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(ip, 4242)
	print(err)
	get_tree().set_network_peer(peer)

	load_game()

func load_game():
	get_tree().change_scene(map)
	yield(get_tree().create_timer(0.01), "timeout")

	spawn = get_tree().get_root().find_node("Spawn", true, false)
	
	spawn_player( get_tree().get_network_unique_id() )

func spawn_player(id):
	var player_instance = load(player).instance()
	player_instance.name = str(id)
	player_instance.set_network_master(id)
	spawn.add_child(player_instance)

func _on_network_peer_connected(id):
	spawn_player(id)
	print("peer connected: " + str(id))
	
func _on_network_peer_disconnected(id):
	print("peer disconnected: " + str(id))
	get_tree().get_root().find_node(str(id), true, false). queue_free()
