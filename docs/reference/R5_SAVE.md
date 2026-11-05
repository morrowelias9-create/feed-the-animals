# R5 — Состояние игры и сохранения

Источник: PLAN_original.md, строка 441.

### R5. Состояние игры и сохранения

**Структура проекта:**

```
autoload/ya.gd, save.gd, loc.gd      каркас
autoload/game.gd                      единственная новая автозагрузка (состояние и операции)
scripts/data/                         только данные: game_config, zone_data, food_data, animal_data, upgrade_data, variant_data
scripts/logic/                        чистые функции без узлов: throw_calc, spawn_roller, economy, ad_policy
scripts/util/                         num_fmt, quality, sound_bank
scripts/world/                        мир и 3D-объекты (world_layout, world_builder, avatar, camera_rig, player,
                                      throw_controller, food_view, reveal_controller, animal_view, model_loader, scenery_builder,
                                      slot_manager, bar_view, bar_controller, expand_sign, zone_look,
                                      tutorial_controller, guide_arrows)
scripts/input/                        input_router, virtual_joystick
scripts/ui/                           ui_style, throw_meter, xp_bar, reveal_overlay, window_base
scenes/main.tscn + main.gd            точка входа
scenes/ui/                            hud, animals_window, shop_window, index_window, offline_window
tests/run_tests.gd                    проверки логики
```

**Контракт `Game`:**

```gdscript
signal money_changed(value: float)
signal strength_changed(value: int)
signal inventory_changed          # список зверей или их размещение изменились
signal slots_changed
signal food_changed               # куплена или выбрана еда
signal bar_changed
signal animal_received(animal: Dictionary)   # {uid, animal_id, variant, placed}
signal boost_changed
signal notice(key: String, args: Array)      # короткие сообщения игроку

func add_money(x: float) -> void
func spend(x: float) -> bool                 # false, если не хватает
func income_per_sec() -> float               # с учётом буста
func add_xp(x: float) -> void                # повышает силу по Economy.xp_needed
func add_animal(animal_id: String, variant: int) -> Dictionary
func place(uid: int) -> bool
func unplace(uid: int) -> void
func sell(uid: int) -> float
func equip_best() -> void
func sell_extras() -> float                  # продаёт неразмещённых редкости 0-1
func buy_food(tier: int) -> bool
func select_food(tier: int) -> void
func buy_bar() -> bool                       # следующий турник
func buy_slots() -> bool                     # следующее расширение
func total_slots() -> int
func placed_animals() -> Array
func claim_zone_reward(zone: int) -> float
func start() -> void                         # после Save.load_all()
func tick(delta: float) -> void              # доход, вызывается из _process автозагрузки
```

Зверь это словарь `{"uid": int, "animal_id": String, "variant": int (0 обычный, 1 золото, 2 бриллиант), "placed": int (0/1)}`. В сохранениях до T10b вместо `variant` было поле `gold` (0/1): `Game.start()` один раз переносит его в `variant`.

**Поля `Save.DEFAULTS`:** `money` (float), `strength` (int, старт 1), `strength_xp` (float), `bar_tier` (int 0-4), `food_unlocked` (int, максимальный купленный тир), `food_selected` (int), `slots_level` (int 0-6), `animals` (Array словарей зверя), `next_uid` (int), `found` (Array id), `claimed_zones` (Array), `best_throw` (int, метры), `throws` (int), `reps` (int), `last_seen` (int, unix), `boost_until` (int, unix), `tutorial_step` (int), `sound_on` (bool, из каркаса), `_ts` (из каркаса). Сохранять по событиям, плюс автосохранение раз в 15 секунд.
