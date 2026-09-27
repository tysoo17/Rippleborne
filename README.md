# Rippleborne

An indie economic game: pixel 2D 3/4 top-down, system-driven RPG. Single-player, PC/Steam first.

> Don't give the player a goal. Give them a world.

![Week 1 test room](docs/images/week1-test-room.png)

## Chạy game

1. Mở Godot **4.7.1**, bấm **Import**, chọn `project.godot` trong thư mục này.
2. Bấm **F5** (Run Project).

| Phím | Tác dụng |
|---|---|
| WASD / mũi tên | Di chuyển |
| F1 / F2 / F3 | (debug) Tua +1 giờ / +1 ngày / +30 ngày |

Sandbox kinh tế: mở `game/economy/sandbox/economy_sandbox.tscn`, bấm **F6**.

Test tự động: mở `tests/test_economy.tscn`, bấm **F6** và xem kết quả ở tab Output. Hoặc chạy
trong terminal: `godot --headless --path . tests/test_economy.tscn`.

## Cấu trúc thư mục

```text
game/
  infrastructure/   EventBus, GameClock (autoload), sau này SaveManager
  player/           Player scene + script
  world/            TileSet, các map/room
  combat/           (tuần 2)
  economy/          (sandbox kinh tế, tuần 5)
  ui/               HUD, DebugOverlay, sau này Market Board
  main.tscn         Scene chạy đầu tiên
assets/             Ảnh, âm thanh (placeholder)
data/               Dữ liệu cân bằng: items, commodities, events, businesses
tests/              Test tự động (headless simulation)
tools/              Công cụ dev
docs/huong-dan/     Giải thích từng bước đã làm
NOT_NOW.md          Ý tưởng để dành, chưa làm trong v0.1
```

## Git workflow

- `main`: bản ổn định, chơi được
- `develop`: nơi gộp các tính năng đã test
- `feature/*`: mỗi tính năng một nhánh, test xong mới gộp vào `develop`
- Tag mốc: `v0.0.1`, `v0.0.5`, `v0.1`

## Tiến độ

- [x] Tuần 1: Foundation ([giải thích](docs/huong-dan/01-foundation.md))
- [x] Sandbox kinh tế: sắt, 2 chợ, quái chiếm/dọn mỏ ([giải thích](docs/huong-dan/02-economy-sandbox.md))
- [ ] Tuần 2: Combat
