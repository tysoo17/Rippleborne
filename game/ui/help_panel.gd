extends GamePanel
## "How to play": controls and a few ideas. There is no mission; the player
## decides what to do.

const TEXT := """You arrive in a small valley. Nobody needs you to save it: the farm feeds
the Town, the mine digs iron, caravans travel, prices change every night.

WASD / arrows  move          Space / J / click  attack (click aims)
Shift / K  dash              E  talk, trade, pick up
I / Tab  bag                  Q  drink a potion
Esc  menu, music on/off      F12  debug panel

Three quick swings make a combo; the third hits hard and breaks a
bandit's guard. An enemy that flashes is about to lunge: dash through!

Some things you could do:
- Hunt in the Forest (south), pick herbs and wood, dig iron, then sell.
- Buy cheap in one market, carry it to the other, sell high.
- Read the Market Board to see what is scarce and WHY.
- When trouble comes (monsters, bandits), deal with it... or profit
  from it. Either way, the world will react."""


func build() -> void:
	custom_minimum_size = Vector2(430, 0)
	set_title("How to play")
	var text := label(TEXT)
	text.add_theme_font_size_override("font_size", 10)
	body.add_child(text)
	body.add_child(button("Let's go", close))
