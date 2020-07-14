extends KinematicBody




var speed = 6
var acceleration = 8
var jump = 4.5
var mouse_sensitivity = 1

var direction = Vector3()
var velocity = Vector3()
var snap = Vector3()
var fall = 0

const GRAVITY = 9.8

var health_float = 100.0
var health = 100
var ammo = 12
var pack = 2

var impact = "res://Instances/Impact.tscn"
var bullet = "res://Instances/Bullet.tscn"
var shell = "res://Instances/Shell.tscn"

var can_shoot = true

puppet var puppet_transform = transform
puppet var puppet_camera_rotation = Vector3()

func _ready():
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	update_HUD()
	
	if is_network_master():
		$Camera.current = true
		$Camera/Angle.visible = false
		$HUD.visible = true
		$Camera/RayCast.enabled = true
		$Camera/Lamp.visible = false
	else:
		$HUD.visible = false

func _input(event):
	if is_network_master():
		if event is InputEventMouseMotion:
			rotation_degrees.y -= event.relative.x * mouse_sensitivity / 10
			$Camera.rotation_degrees.x = clamp($Camera.rotation_degrees.x - event.relative.y * mouse_sensitivity / 10, -90, 90)
	
		direction.z = -Input.get_action_strength("move_forward") + Input.get_action_strength("move_backward")
		direction.x = -Input.get_action_strength("move_left") + Input.get_action_strength("move_right")
		direction = direction.normalized().rotated(Vector3.UP, rotation.y)
		
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			snap = Vector3()
			fall = jump
		rset_unreliable("puppet_camera_rotation", $Camera.rotation)
	else:
		$Camera.rotation = puppet_camera_rotation
	
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene("res://Lobby.tscn")
	
func _physics_process(delta):
	if is_network_master():
		
		fall -= GRAVITY * delta
		if is_on_floor() and not Input.is_action_just_pressed("jump"):
			snap = Vector3.DOWN * 0.1
			fall = 0
	
		velocity = velocity.linear_interpolate(direction * speed, acceleration * delta)
		move_and_slide_with_snap(Vector3(velocity.x, fall, velocity.z), snap, Vector3.UP, true, 4, deg2rad(45))
		
		
		if $Camera/Handgun/AnimationPlayer.current_animation != "fire" and $Camera/Handgun/AnimationPlayer.current_animation != "reload" and $Camera/Handgun/AnimationPlayer.current_animation != "pull out":
		
			if direction != Vector3():
				rpc("animation", "walk")
				if not Input.is_action_pressed("sprint"):
					rpc("footstep", true, 1.0)
					speed = 10
				else:
					rpc("footstep", true, 1.1)
					speed = 16
			else:
				rpc("animation", "idle")
				rpc("footstep", false, 1.0)
		
		
		if health <= 0:
			global_transform = Network.spawn.global_transform
			yield(get_tree().create_timer(.01), "timeout")

			health_float = 100
			update_HUD()
		
		rset_unreliable("puppet_transform", transform)
		other_abilities()

		
	else:
		transform = puppet_transform
		$Camera.rotation = puppet_camera_rotation








func other_abilities():
	if Input.is_action_just_pressed("shoot"):
		if can_shoot and $Camera/Handgun/AnimationPlayer.current_animation != "reload":
			if ammo > 0:
				ammo -= 1
				update_HUD()
				
				rpc("shoot")
				
				can_shoot = false
				$Timer.start()
				
				rpc("animation", "fire")
				if $Camera/RayCast.is_colliding():
					if $Camera/RayCast.get_collider().is_in_group("Zombie"):
						$Camera/RayCast.get_collider().rpc("shot")
					else:
						if not $Camera/RayCast.get_collider().is_in_group("Player"):
							rpc("impact", $Camera/RayCast.get_collision_point())
			else:
				rpc("empty_sound")
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("reload") and ammo != 12:
		if pack > 0:
			rpc("reload")
			ammo = 12
			pack -= 1
			update_HUD()
	
	
	if Input.is_action_just_pressed("flashlight"):
		$Camera/Flashlight.visible = !$Camera/Flashlight.visible
		rpc("toggle_light", $Camera/Flashlight.visible)

remotesync func empty_sound():
	$Camera/Nozzle/EmptySound.play()

remotesync func footstep(status, pitch):
	if not $FootStep.playing:
		if status:
			$FootStep.pitch_scale = pitch
			$FootStep.play()
		else:
			$FootStep.stop()

remotesync func impact(position):
	var impact_instance = load(impact).instance()
	impact_instance.global_transform.origin = position
	get_tree().get_root().get_node("Game").add_child(impact_instance)

func heal():
	health_float += 50
	if health_float > 100:
		health_float = 100
	health = int(health_float)
	update_HUD()

remotesync func attacked(delta):
	health_float -= 30 * delta
	update_HUD()
	rpc("hurt_sound")

remotesync func hurt_sound():
	if $Hurt1.playing == false and $Hurt2.playing == false:
		var number = rand_range(0,2)
		if number < 1:
			$Hurt1.play()
		else:
			$Hurt2.play()
	
remotesync func reload():
	$Camera/Handgun/AnimationPlayer.play("reload")
	$Camera/Nozzle/ReloadSound.play()

func update_HUD():
	health = int(health_float)
	$HUD/Health.text = str (health)
	$HUD/Ammo.text = str( ammo ) + " / " + str(pack)

remotesync func animation(anim):
	$Camera/Handgun/AnimationPlayer.play(anim)

remotesync func toggle_light(status):
	$Camera/Flashlight.visible = status
	$Camera/Lamp/Feedback.visible = status

remotesync func shoot():
	$Camera/Nozzle/ShootSound.play()
	$Camera/ShootLight.visible = true
	$ShootLightTimer.start()

	var bullet_instance = load(bullet).instance()
	bullet_instance.global_transform = $Camera/Nozzle.global_transform
	get_tree().get_root().get_node("Game").add_child(bullet_instance)
	bullet_instance.linear_velocity = $Camera.global_transform.basis.z * -200
	
	var shell_instance = load(shell).instance()
	shell_instance.global_transform = $Camera/ShellPosition.global_transform
	get_tree().get_root().get_node("Game").add_child(shell_instance)
	shell_instance.linear_velocity = $Camera/ShellPosition.global_transform.basis.x * 5
	
	yield(get_tree().create_timer(2), "timeout")
	bullet_instance.queue_free()


func _on_network_peer_connected(id):
	if is_network_master():
		rpc("toggle_light", $Camera/Flashlight.visible)
		rset("puppet_camera_rotation", $Camera.rotation)

func _on_Timer_timeout():
	can_shoot = true

func _on_ShootLightTimer_timeout():
	$Camera/ShootLight.visible = false
	rpc("shootlight", false)