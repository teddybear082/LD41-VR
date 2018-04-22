extends KinematicBody

export var speed = 1
var dir = Vector3()
var vel = Vector3()
const GRAVITY = -9.8

var life = 100
var dead = false


func _physics_process(delta):
	
	if dead:
		$ZombieModel/AnimationPlayer.stop()
		return
	
	$ZombieModel/AnimationPlayer.queue("ArmatureAction")
	
	self.look_at(Game.player.translation, Vector3(0,1,0))  
	
	dir = Game.player.translation - self.translation
	dir.y = 0
	dir = dir.normalized()

	vel.y += GRAVITY * delta
	
	var tmp_vel = vel
	tmp_vel.y = 0

	# where would the zombie go at max speed
	var target = dir * speed
	
	# calculate a portion of the distance to go
	tmp_vel = tmp_vel.linear_interpolate(target, 12 * delta)
	
	vel.x = tmp_vel.x
	vel.z = tmp_vel.z

	vel = move_and_slide(vel, Vector3(0, 1, 0))

func hit(damage, position):
	if not dead:
		life -= damage
		hit_particle(position)
		if life <= 0:
			die()
		
func die():
	dead = true
	$DeadTimer.start()
	
func hit_particle(position):
	$HitParticle.emitting = true
	$HitParticle.restart()

func _on_DeadTimer_timeout():
	self.queue_free()