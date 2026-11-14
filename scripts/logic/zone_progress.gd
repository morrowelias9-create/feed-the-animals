class_name ZoneProgress
extends RefCounted
## Управляет прогрессом достижения биомов (зоны).
## Биом считается достигнутым только после фактического приземления еды в нём.

static func has_reached_zone(zone: int) -> bool:
	var reached: Array = Save.data.get("reached_zones", [])
	return reached.has(zone)


static func record_reached_zone(zone: int) -> bool:
	if zone < 0 or zone >= ZoneData.count():
		return false
	
	var reached: Array = Save.data.get("reached_zones", [])
	
	# Если зона уже достигнута, ничего не делаем
	if reached.has(zone):
		return false
	
	# Все предыдущие зоны также считаются достигнутыми
	for z in range(zone + 1):
		if not reached.has(z):
			reached.append(z)
	
	# Сортируем для порядка
	reached.sort()
	
	Save.data["reached_zones"] = reached
	Save.save_data()
	return true


static func ensure_migrated() -> void:
	# Убеждаемся, что reached_zones существует и является массивом
	if not Save.data.has("reached_zones") or not (Save.data["reached_zones"] is Array):
		Save.data["reached_zones"] = []
	
	var reached: Array = Save.data["reached_zones"]
	
	# Зона 0 (Лес) всегда открыта
	if not reached.has(0):
		reached.append(0)
	
	# Восстанавливаем прогресс из best_throw для старых сохранений
	var best_throw: int = int(Save.data.get("best_throw", 0))
	if best_throw > 0:
		var max_zone: int = ZoneData.zone_at(float(best_throw))
		for z in range(max_zone + 1):
			if not reached.has(z):
				reached.append(z)
	
	# Удаляем некорректные индексы
	var valid: Array = []
	for z in reached:
		if z >= 0 and z < ZoneData.count():
			valid.append(z)
	valid.sort()
	Save.data["reached_zones"] = valid
	
	# Очищаем уведомления о покупке еды для недостигнутых зон
	_clear_notifications_for_unreached()


static func _clear_notifications_for_unreached() -> void:
	var notified: Array = Save.data.get("food_notified", [])
	var reached: Array = Save.data.get("reached_zones", [])
	var cleaned: Array = []
	
	for tier in notified:
		var zone: int = FoodData.zone_of(tier)
		if reached.has(zone):
			cleaned.append(tier)
	
	if cleaned.size() != notified.size():
		Save.data["food_notified"] = cleaned
		Save.save_data()