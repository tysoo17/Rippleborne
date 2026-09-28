extends GamePanel
## Job board: deliveries this settlement needs and bounties on trouble.
## Nothing here is scripted - jobs appear from shortages and events.

var _reputation: Label
var _rows: VBoxContainer
var _message: Label


func build() -> void:
	custom_minimum_size = Vector2(440, 0)
	_reputation = label("")
	body.add_child(_reputation)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	body.add_child(_rows)
	_message = label("", 0.0, Color(1, 0.75, 0.5))
	body.add_child(_message)
	var note := label("Deliveries go straight into this market's stock. Bounties pay when you end the trouble yourself. Good work raises your reputation, and friends get better prices.", 0.0, Color(0.65, 0.62, 0.58))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 420
	note.add_theme_font_size_override("font_size", 10)
	body.add_child(note)


func settlement() -> StringName:
	return context.get("settlement", &"town")


func refresh() -> void:
	var s := settlement()
	set_title("%s job board" % Game.settlement_name(s))
	var points := Game.jobs.reputation_of(s)
	_reputation.text = "Your reputation here: %s (%d/100)    Shop margin: %d%%" % [
			JobSystem.title_for(points), points, roundi(Game.economy.shop_margin(s) * 100)]
	for child in _rows.get_children():
		child.queue_free()
	var jobs := Game.jobs.jobs_for(s)
	if jobs.is_empty():
		_rows.add_child(label("No work posted today. Come back when something runs short.", 0.0, Color(0.7, 0.7, 0.7)))
	for job in jobs:
		_rows.add_child(_row(job))


func _row(job: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if job.kind == "deliver":
		row.add_child(icon(Game.items[StringName(job.commodity)].icon))
		var have := Game.player.inventory.count_of(StringName(job.commodity))
		row.add_child(label(job.text, 230.0))
		row.add_child(label("%d g" % job.reward, 44.0, Color(1, 0.85, 0.4)))
		row.add_child(label("%d day%s" % [job.days_left, "" if job.days_left == 1 else "s"], 44.0, Color(0.7, 0.7, 0.7)))
		var deliver := button("Deliver (%d/%d)" % [mini(have, job.amount), job.amount], _deliver.bind(job))
		deliver.disabled = have < int(job.amount)
		row.add_child(deliver)
	else:
		row.add_child(icon(preload("res://assets/icons/bandit_insignia.png")))
		row.add_child(label("BOUNTY: " + job.text, 230.0, Color(1, 0.6, 0.45)))
		row.add_child(label("%d g" % job.reward, 44.0, Color(1, 0.85, 0.4)))
		row.add_child(label("paid when done", 100.0, Color(0.7, 0.7, 0.7)))
	return row


func _deliver(job: Dictionary) -> void:
	var problem := Game.jobs.deliver(job, Game.economy, Game.player)
	if problem != "":
		_message.text = problem
		return
	_message.text = "Delivered! +%d gold." % job.reward
	Sfx.play(&"coin")
	refresh()
