extends GamePanel
## The inn: sleep until morning to heal (and save the game).

const PRICE := 3

var _info: Label
var _sleep_button: Button


func build() -> void:
	custom_minimum_size = Vector2(300, 0)
	set_title("The Sleepy Pickaxe Inn")
	_info = label("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 280
	body.add_child(_info)
	_sleep_button = button("Sleep", _sleep)
	body.add_child(_sleep_button)


func refresh() -> void:
	var gossip := "Greta the innkeeper wipes a mug: \"%s\"

" % Dialogue.news(&"innkeeper")
	if Game.player.money >= PRICE:
		_info.text = gossip + "A warm bed until morning costs %d gold. You wake up with full health, and the game is saved." % PRICE
		_sleep_button.text = "Sleep (%d gold)" % PRICE
	else:
		_info.text = gossip + "No money? You can sleep in the stable for free. You will only recover half your health."
		_sleep_button.text = "Sleep in the stable"


func _sleep() -> void:
	var p := Game.player
	if p.money >= PRICE:
		p.money -= PRICE
		p.hp = p.max_hp
	else:
		p.hp = maxi(p.hp, p.max_hp / 2)
	close()
	GameClock.advance_to_next_morning()
	var saved := SaveManager.save_game()
	EventBus.news.emit("Good morning! Day %d.%s" % [GameClock.day, " Game saved." if saved else ""], "good")
