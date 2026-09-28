class_name Dialogue
extends RefCounted
## What NPCs say. Every line is picked from the current state of the world,
## so talking to people is a real way to learn what is going on - and what
## is about to happen.
##
## Roles: farmer, miner, villager, guard, townsperson, merchant, innkeeper.


## First thing an NPC says when you talk to them.
static func greeting(role: StringName, settlement: StringName) -> String:
	var world := Game.world
	match role:
		&"farmer":
			if world.modifiers.has("wolves_at_farm"):
				return "Those wolves again! They scare off the pickers, we lose half the harvest."
			if world.modifiers.has("harvest_festival"):
				return "Festival week! Everyone wants bread. Good for us, hard on the back."
			if _price_ratio(&"town", &"food") > 1.3:
				return "Food is dear right now, but crops don't grow any faster for it."
			return "Good soil, good rain. This farm feeds the whole Town."
		&"miner":
			if world.mine_infested:
				return "We ran for our lives. Nobody goes back in until those things are gone."
			if Game.economy.market(&"village", &"food").satisfaction() < 0.9:
				return "Bread costs %d here now. Hard to swing a pick on an empty stomach." % \
						Game.economy.buy_price(&"village", &"food")
			if world.modifiers.has("rich_vein"):
				return "We hit a rich vein! Best week of digging in years."
			return "Iron doesn't dig itself. Twenty loads a day, as long as we're fed."
		&"villager":
			if world.modifiers.has("cold_snap"):
				return "Brr! Firewood is worth its weight in gold this week."
			if world.bandits_active:
				return "The caravans stopped coming. We live on whatever is left in the stores."
			return "This village lives off the mine. When the mine sneezes, we all catch a cold."
		&"guard":
			if world.bandits_active:
				return "Bandits by the road, %d of them at least. There's a bounty on the job board." % world.bandits_left
			if Game.events.is_pending(&"bandit_activity"):
				return "Travellers talk about armed men in the woods north of the road. Keep your eyes open."
			return "Road's quiet. Caravans come and go, that's how I like it."
		&"townsperson":
			if world.modifiers.has("big_order"):
				return "The blacksmith has been hammering day and night. Some big order, they say."
			if world.modifiers.has("harvest_festival"):
				return "Music, dancing, pies! Don't miss the festival, dear."
			return "Do you read the market board? My son checks it every morning before he buys anything."
		&"merchant":
			return price_tip(settlement)
	return "Hello there."


## Answer to "Any news?": rumours first, then whatever is happening now.
static func news(role: StringName) -> String:
	var rumors := Game.events.rumors()
	if not rumors.is_empty():
		return "Between you and me... " + rumors[0]
	var world := Game.world
	if world.mine_infested:
		return "Monsters in the mine, %d still down there. No iron until someone clears them out." % world.mine_monsters_left
	if world.bandits_active:
		return "Bandits camp north of the road. The caravans are too scared to travel."
	for m: Dictionary in world.modifiers.values():
		return String(m.news)
	if role == &"merchant":
		return "Quiet times. Good for honest trade."
	return "Nothing new, I'm afraid. Quiet times."


## A merchant compares the two markets and tells you where the money is.
static func price_tip(settlement: StringName) -> String:
	var other := &"village" if settlement == &"town" else &"town"
	var best_id: StringName = &""
	var best_ratio := 1.0
	for id in Game.COMMODITY_IDS:
		var here := Game.economy.market(settlement, id).price
		var there := Game.economy.market(other, id).price
		var ratio := there / here
		if ratio > best_ratio:
			best_ratio = ratio
			best_id = id
	if best_id == &"" or best_ratio < 1.15:
		return "Prices here and in %s are close these days. Not much to gain carrying goods." % Game.settlement_name(other)
	var item_name: String = Game.economy.commodities[best_id].display_name.to_lower()
	return "A tip, friend: %s costs %.0f here, but in %s they pay about %.0f." % [
		item_name, Game.economy.market(settlement, best_id).price, Game.settlement_name(other),
		Game.economy.market(other, best_id).price]


static func _price_ratio(settlement: StringName, id: StringName) -> float:
	var m := Game.economy.market(settlement, id)
	return m.price / m.commodity.base_price
