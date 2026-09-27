extends GamePanel
## "How to play": controls and a few ideas. There is no mission; the player
## decides what to do.

const TEXT := """You arrive in a small valley. Nobody needs you to save it.
It keeps living on its own: the farm feeds the Town, the mine in the east
digs iron, caravans carry goods along the road, and prices change every night.

WASD / arrows  move          Space / J / click  attack
Shift / K  dash              E  talk, trade, pick up
I / Tab  bag                  Q  drink a potion
Esc  menu                    F12  debug panel

Some things you could do:
- Hunt slimes and wolves in the Forest (south) and sell what they drop.
- Pick herbs and wood, or dig iron in the Mine, and sell them.
- Buy cheap in one market, carry it to the other, sell high.
- Read the Market Board to see what is scarce and WHY.
- When trouble comes (monsters, bandits), you can deal with it...
  or profit from it. Either way, the world will react."""


func build() -> void:
	custom_minimum_size = Vector2(430, 0)
	set_title("How to play")
	var text := label(TEXT)
	text.add_theme_font_size_override("font_size", 10)
	body.add_child(text)
	body.add_child(button("Let's go", close))
