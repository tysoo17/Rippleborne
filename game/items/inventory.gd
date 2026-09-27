class_name Inventory
extends RefCounted
## A fixed number of slots; each slot is empty (null) or {"id": StringName, "count": int}.

const SIZE := 20

var slots: Array = []
var _items: Dictionary  # id -> ItemData, to know stack sizes


func _init(items: Dictionary) -> void:
	_items = items
	slots.resize(SIZE)


## Adds items, filling existing stacks first. Returns how many did NOT fit.
func add(id: StringName, count: int) -> int:
	var max_stack: int = _items[id].max_stack
	var left := count
	for slot in slots:
		if left > 0 and slot != null and slot.id == id and slot.count < max_stack:
			var moved := mini(left, max_stack - slot.count)
			slot.count += moved
			left -= moved
	for i in SIZE:
		if left > 0 and slots[i] == null:
			var moved := mini(left, max_stack)
			slots[i] = {"id": id, "count": moved}
			left -= moved
	if left != count:
		EventBus.inventory_changed.emit()
	return left


## Removes items if there are enough. Returns false (and removes nothing) otherwise.
func remove(id: StringName, count: int) -> bool:
	if count_of(id) < count:
		return false
	var left := count
	for i in range(SIZE - 1, -1, -1):
		var slot = slots[i]
		if left > 0 and slot != null and slot.id == id:
			var taken := mini(left, int(slot.count))
			slot.count -= taken
			left -= taken
			if slot.count <= 0:
				slots[i] = null
	EventBus.inventory_changed.emit()
	return true


func count_of(id: StringName) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot.id == id:
			total += slot.count
	return total


## How many of this item could still be added.
func space_for(id: StringName) -> int:
	var max_stack: int = _items[id].max_stack
	var space := 0
	for slot in slots:
		if slot == null:
			space += max_stack
		elif slot.id == id:
			space += max_stack - slot.count
	return space


func to_array() -> Array:
	var result := []
	for slot in slots:
		result.append(null if slot == null else {"id": String(slot.id), "count": slot.count})
	return result


func from_array(saved: Array) -> void:
	slots.clear()
	slots.resize(SIZE)
	for i in mini(saved.size(), SIZE):
		var slot = saved[i]
		if slot != null and _items.has(StringName(slot.id)):
			slots[i] = {"id": StringName(slot.id), "count": int(slot.count)}
	EventBus.inventory_changed.emit()
