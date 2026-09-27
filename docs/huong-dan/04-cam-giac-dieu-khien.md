# Bước 4: Gói A, cảm giác điều khiển ("game feel")

Sau lần chơi thử đầu, bạn thấy điều khiển và đánh nhau chán. Gói này không thêm hệ thống mới, chỉ làm cho **mỗi thao tác có cảm giác**.

## Thử ngay (bạn làm)

F5 → New game → xuống Forest (cổng phía nam Town):

- Đi rồi dừng: nhân vật **tăng tốc và giảm tốc mượt**, camera **nhìn trước** theo hướng đi, có **bụi** dưới chân khi chạy.
- Chém 3 lần liên tiếp: **combo**. Nhát 3 to hơn, mạnh hơn (+1 sát thương), đẩy lùi xa và khựng hình lâu hơn. Bấm hơi sớm vẫn được tính (input buffer).
- Click chuột trái: chém **về phía con trỏ**.
- Chém trúng: **khựng hình** vài phần trăm giây, **tia lửa**, **rung màn hình**, quái bị **choáng** một chút.
- Shift: **dash** để lại **bóng mờ** phía sau, và không bị đánh trúng khi đang lướt.
- Quái chết: **nổ bụi** theo màu của nó; đồ rơi **nảy ra** rồi mới nằm yên.
- **Sói** lao 2 lần liên tiếp. **Cướp** đỡ được đòn thường ("Block!") rồi phản công ngay, nhưng **nhát combo thứ 3 phá được thế đỡ**. **Slime** chết thì tách thành 2 slime nhỏ.
- Quái **nhấp nháy và run** ngay trước khi lao tới: đó là lúc nên dash.
- **Nhạc nền** đổi theo khu vực: Town và làng có một bài, đường và rừng một bài, Mine một bài. Tắt hoặc bật trong **Esc → Music / Sound**.

## Chỉnh cảm giác mà không cần code

Mở `game/player/player.tscn`, bấm node **Player**. Trong Inspector có 3 nhóm:

| Nhóm | Ô | Ý nghĩa |
|---|---|---|
| Movement | Speed, Acceleration, Friction | Tốc độ, độ nhanh đạt tốc độ, độ nhanh dừng lại |
| | Dash Speed / Time / Cooldown | Lướt nhanh, dài và thường xuyên đến đâu |
| | Camera Lead | Camera nhìn trước bao xa (0 = không) |
| Attack | Attack Time / Cooldown | Nhát chém dài bao lâu, bao lâu chém được lần nữa |
| | Combo Window | Thời gian để nối nhát tiếp theo vào combo |
| | Input Buffer | Bấm sớm bao nhiêu vẫn tính |
| | Attack Step | Bước tới trước mỗi nhát chém |
| Getting hurt | Hurt Invincibility | Bất tử bao lâu sau khi bị đánh |

Quái (`data/enemies/*.tres`), nhóm **Special Moves**:

- **Lunge Count**: số lần lao liên tiếp (sói = 2).
- **Block Chance**: tỉ lệ đỡ đòn thường (cướp = 0.35).
- **Split Into** và **Split Count**: chết thì tách thành gì, bao nhiêu con (slime → 2 `mini_slime`).
- **Sprite Scale**: vẽ to hay nhỏ (slime nhỏ = 0.6). Chiều cao hình giờ **tự tính từ ảnh**, nên khi thay ảnh quái bạn không cần chỉnh chiều cao nữa.

## Code mới ở đâu

| File | Nội dung |
|---|---|
| `game/infrastructure/feel.gd` (autoload **Feel**) | `Feel.hit_stop()`, `Feel.shake()`, `Feel.burst()` (tia lửa, bụi, nổ bụi, đỡ đòn) |
| `game/infrastructure/sfx.gd` | Thêm nhạc nền: `Sfx.play_music()`, chuyển bài mượt, tự đổi theo khu vực, lưu lựa chọn bật/tắt vào `user://settings.cfg` |
| `game/player/player.gd` | Tăng tốc và giảm tốc, nhắm chuột, combo, input buffer, vệt chém chuyển động, bóng mờ khi dash, camera nhìn trước và rung |
| `game/combat/enemy.gd` | Trạng thái choáng, lao nhiều lần, đỡ đòn và phản công, tách đôi, hiệu ứng khi trúng đòn và khi chết |
| `game/items/item_pickup.gd` | Đồ rơi nảy lên theo đường cong |
| `assets/sprites/slash_sheet.png` | Vệt chém 4 khung |
| `assets/music/*.wav` | 3 bản nhạc do mình tổng hợp bằng code (placeholder, thay bằng nhạc thật bất cứ lúc nào, giữ nguyên tên file) |

**Khựng hình (hit-stop)** hoạt động bằng cách cho cả game chạy chậm 20 lần trong khoảng 0.05 đến 0.09 giây. Nhờ vậy não người chơi kịp "cảm" được cú đánh. Đây là mẹo phổ biến trong game hành động.

## Test

`tests/test_gameplay.tscn` có thêm 8 kiểm tra: tăng/giảm tốc, combo 3 nhát, cướp đỡ đòn, nhát 3 phá thế đỡ, sói lao 2 lần, slime tách đôi. Tổng cộng **35/35 đạt**. `tests/test_simulation.tscn` vẫn **23/23 đạt**.

## Giới hạn

- Nhạc và âm thanh là tổng hợp bằng code, nghe "8-bit" đơn giản. Bạn có thể thay bằng nhạc thật (định dạng `.wav` hoặc `.ogg`, giữ tên file hoặc sửa đường dẫn trong `sfx.gd`).
- Nhân vật chưa có tư thế chém riêng (sprite sheet vẫn là 4 × 4 như hướng dẫn đồ họa); cảm giác chém đến từ vệt chém, bước tới và co giãn nhẹ.
