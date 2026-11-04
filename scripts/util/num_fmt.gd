class_name NumFmt
extends RefCounted
## Форматирование больших чисел: 3 значащие цифры и суффиксы K M B T Qa Qi Sx.

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx"]


## 2360 -> "2.36K", 999 -> "999", 1.2e6 -> "1.2M". Отрицательные и NaN дают "0".
static func format(x: float) -> String:
	if is_nan(x) or x <= 0.0:
		return "0"
	if is_inf(x):
		return "∞"
	var v: float = x
	var idx: int = 0
	var last: int = SUFFIXES.size() - 1
	while true:
		# Знаков после запятой так, чтобы вышло 3 значащие цифры.
		var decimals: int = 0
		if idx > 0:
			if v < 10.0:
				decimals = 2
			elif v < 100.0:
				decimals = 1
		var r: float = snappedf(v, pow(10.0, -decimals))
		if r >= 1000.0 and idx < last:
			# После округления вышло 1000: переходим к следующему суффиксу.
			v = r / 1000.0
			idx += 1
			continue
		if idx == 0:
			return str(int(r))
		return _trim(("%." + str(decimals) + "f") % r) + SUFFIXES[idx]
	return "0"  # недостижимо, нужно только для разбора скрипта


## Деньги с символом доллара: 2360 -> "$2.36K".
static func money(x: float) -> String:
	return "$" + format(x)


# Убирает хвостовые нули и точку: "1.20" -> "1.2", "5.00" -> "5".
static func _trim(s: String) -> String:
	if s.find(".") == -1:
		return s
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s
