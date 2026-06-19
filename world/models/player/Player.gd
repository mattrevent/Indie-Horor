extends CharacterBody3D

# Ссылка на узел-голову (убедись, что дочерний узел называется именно Head)
@onready var head = $Head
@onready var flashlight = $Head/Camera3D/flashlight
@onready var flashlight_light = $Head/Camera3D/flashlight/flashlight_light
@onready var battery_bar = $UI/BatteryBar
@onready var interaction_ray = $Head/Camera3D/InteractionRay
@onready var crosshair: TextureRect = $UI/Crosshair
@onready var omni_light_3d: OmniLight3D = $"../Lamp/lamp_model/OmniLight3D"



# Настраиваем чувствительность
var mouse_sensitivity = 0.003

var max_battery : float = 100.0
var current_battery : float = 100.0
var drain_rate : float = 1.0  # сколько единиц заряда тратится в секунду
var on_hand : bool = true

const DROPPED_FLASHLIGHT = preload("res://world/models/flashlight/dropped_flashlight.tscn")
const CROSSHAIR_IDLE = preload("res://world/assets/crosshair_normal.png")
const CROSSHAIR_INTERACT = preload("res://world/assets/crosshair_interact.png")

func _ready():
	# Захватываем и прячем курсор при запуске сцены
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)	

func _unhandled_input(event):
	# Проверяем, является ли событие именно движением мыши
	if event is InputEventMouseMotion:
		# Поворачиваем всё тело влево-вправо (вокруг вертикальной оси Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Поворачиваем только голову вверх-вниз (вокруг оси X)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Ограничиваем наклон головы (функция clamp), чтобы герой не сломал шею, смотря слишком далеко за спину
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	# Проверяем, нажал ли игрок кнопку фонарика
	if event.is_action_pressed("toggle_flashlight") and on_hand:
		flashlight_light.visible = not flashlight_light.visible
	# Выбрасываем предмет, только если нажата кнопка И фонарик в руках
	if event.is_action_pressed("drop_item") and on_hand:
		var drop = DROPPED_FLASHLIGHT.instantiate()
		get_tree().root.add_child(drop)
		# Складываем позицию камеры и направление "вперед"
		drop.global_position = $Head/Camera3D.global_position - $Head/Camera3D.global_transform.basis.z
		
		# Обновляем состояние инвентаря
		on_hand = false
		flashlight.visible = false  # Прячем фонарик в руке
	
	
	if event.is_action_pressed("interact"):
		if interaction_ray.is_colliding():
			var hit_object = interaction_ray.get_collider()
			if hit_object.is_in_group("Lamp"):
				omni_light_3d.visible = not omni_light_3d.visible
			elif hit_object.is_in_group("Flashlight") and not on_hand:
				hit_object.queue_free()    # Удаляем объект с пола
				on_hand = true             # Отмечаем, что предмет в руках
				flashlight.visible = true  # Показываем модельку в руках



# Получаем значение гравитации из настроек проекта Godot
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
const SPEED = 5.0

func _physics_process(delta):
	# 1. Применяем гравитацию, если игрок в воздухе
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Получаем направление движения от клавиатуры (WASD)
	# Перед этим нужно настроить эти действия в Project -> Project Settings -> Input Map
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Рассчитываем направление относительно того, куда повернут игрок
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# 3. Двигаем персонажа с учетом всех сил
	move_and_slide()
	
	
	# Логика батарейки
	if flashlight_light.visible and on_hand:
		current_battery -= drain_rate * delta
		
		if current_battery <= 0:
			flashlight_light.visible = false
			current_battery = 0
			
		# Синхронизируем значение на экране с переменной в коде
		battery_bar.value = current_battery
		
	# --- Логика прицела со сменой изображений ---
	
	# Сначала всегда устанавливаем обычный прицел (как состояние по умолчанию)
	crosshair.texture = CROSSHAIR_IDLE
	
	# Убедись, что цвет прицела (modulate) белый, чтобы он не красил картинку
	crosshair.modulate = Color.WHITE


	if interaction_ray.is_colliding():
		var hit_object = interaction_ray.get_collider()
		
		if hit_object:
			if hit_object.is_in_group("Lamp"):
				crosshair.texture = CROSSHAIR_INTERACT
			elif hit_object.is_in_group("Flashlight") and not on_hand:
				crosshair.texture = CROSSHAIR_INTERACT
