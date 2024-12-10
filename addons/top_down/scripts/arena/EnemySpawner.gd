class_name EnemySpawner
extends Node

@export var enemy_instance_resource:InstanceResource
@export var spawn_mark_instance_resource:InstanceResource
@export var spawn_partickle_instance_resource:InstanceResource
@export var enemy_count_resource:IntResource
@export var spawn_point_resource:SpawnPointResource
@export var fight_mode_resource:BoolResource

var max_active_count:int
var allowed_count:int

func _ready()->void:
	assert(enemy_count_resource != null)
	assert(spawn_point_resource != null)
	assert(enemy_instance_resource != null)
	assert(spawn_mark_instance_resource != null)
	assert(fight_mode_resource != null)
	
	fight_mode_resource.changed_true.connect(set_process.bind(true))
	fight_mode_resource.changed_false.connect(set_process.bind(false))
	set_process(fight_mode_resource.value)
	tree_exiting.connect(_cleanup)
	
	_setup_active_count.call_deferred()

func _setup_active_count()->void:
	# TODO: best not to limit to spawn point count, maybe sum of enemy threat value
	max_active_count = spawn_point_resource.position_list.size()
	allowed_count = max_active_count

func _cleanup()->void:
	spawn_point_resource.position_list.clear()

func _process(delta: float) -> void:
	if enemy_count_resource.value < max_active_count:
		return
	if allowed_count < 1:
		return
	var _active_count:int = enemy_instance_resource.active_list.size() + spawn_mark_instance_resource.active_list.size()
	if _active_count >= max_active_count:
		return
	
	_create_spawn_mark()

func _create_spawn_mark()->void:
	var _free_positions:Array[Vector2] = spawn_point_resource.position_list.filter(_filter_free_position)
	if _free_positions.is_empty():
		return
	
	allowed_count -= 1
	var _spawn_position:Vector2 = _free_positions.pick_random()
	
	## after despawning creates actual enemy
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _spawn_position
		inst.tree_exiting.connect(_create_enemies.bind(_spawn_position), CONNECT_ONE_SHOT)
	spawn_mark_instance_resource.instance(_config_callback)

func _create_enemies(spawn_position:Vector2)->void:
	var _partickle_config:Callable = func(inst:Node2D)->void:
		inst.global_position = spawn_position
	spawn_partickle_instance_resource.instance(_partickle_config)
	
	var _enemy_config:Callable = func (inst:Node2D)->void:
		inst.global_position = spawn_position
		inst.tree_exiting.connect(_erase_enemy.bind(inst), CONNECT_ONE_SHOT)
	
	enemy_instance_resource.instance(_enemy_config)

func _erase_enemy(node:Node2D)->void:
	enemy_count_resource.set_value(enemy_count_resource.value -1)
	allowed_count += 1

func _filter_free_position(position:Vector2)->bool:
	# distance squared
	const FREE_DISTANCE:float = 116.0 * 116.0
	
	var _closest_dist:float = 999999.0
	## Actual enemy instances
	for inst:Node2D in enemy_instance_resource.active_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	# Spawn markers
	for inst:Node2D in spawn_mark_instance_resource.active_list:
		# for finding closest length_squared is great, since it is faster without using square root.
		var _inst_dist:float = (inst.global_position - position).length_squared()
		if _inst_dist < _closest_dist:
			_closest_dist = _inst_dist
	
	# free distance was squared because it is compared againsts length_squared
	return _closest_dist > FREE_DISTANCE
