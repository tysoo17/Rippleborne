class_name EnemyData
extends Resource
## Static data for one enemy type. One Enemy scene + different data files
## gives Slime, Cave Slime, Wolf and Bandit.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Look")
@export var texture: Texture2D
@export var hframes: int = 2
@export var tint: Color = Color.WHITE
## Height of one frame in pixels (the sprite is drawn above the feet).
@export var frame_height: float = 20.0
@export var body_radius: float = 7.0

@export_group("Stats")
@export var max_hp: int = 3
@export var damage: int = 1
## Hurts the player just by touching (slimes).
@export var contact_damage: bool = false
@export var wander_speed: float = 25.0
@export var chase_speed: float = 55.0
@export var detect_range: float = 110.0
@export var attack_range: float = 30.0
## Seconds the enemy telegraphs (flashes) before lunging.
@export var attack_windup: float = 0.4
@export var lunge_speed: float = 170.0
@export var attack_cooldown: float = 1.2
## 1 = normal knockback, 0 = cannot be pushed.
@export var knockback_taken: float = 1.0

@export_group("Loot")
@export var gold_min: int = 0
@export var gold_max: int = 0
@export var loot_items: Array[StringName] = []
## Chance (0..1) for each entry of loot_items.
@export var loot_chances: Array[float] = []
