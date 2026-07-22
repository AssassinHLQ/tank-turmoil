import math
import random
import tkinter as tk

WIDTH, HEIGHT = 1000, 700
HUD_H = 72
CELL = 70
COLS, ROWS = 13, 8
OX = (WIDTH - COLS * CELL) // 2
OY = HUD_H + (HEIGHT - HUD_H - ROWS * CELL) // 2
TANK_R = 18
BG = "#10161f"
FIELD = "#192330"
WALL = "#d9e2d0"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


class Tank:
    def __init__(self, x, y, angle, color, name, controls):
        self.x, self.y, self.angle = x, y, angle
        self.color, self.name, self.controls = color, name, controls
        self.cooldown = 0
        self.alive = True


class Bullet:
    def __init__(self, x, y, angle, owner):
        speed = 7.2
        self.x, self.y = x, y
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed
        self.owner = owner
        self.life = 660
        self.grace = 16


class Game:
    def __init__(self, root):
        self.root = root
        self.root.title("坦克动荡 · 离线双人版")
        self.root.resizable(False, False)
        self.canvas = tk.Canvas(root, width=WIDTH, height=HEIGHT, bg=BG, highlightthickness=0)
        self.canvas.pack()
        self.keys = set()
        self.scores = [0, 0]
        self.round_over = False
        self.paused = False
        self.message = ""
        self.walls = []
        self.bullets = []
        root.bind("<KeyPress>", self.key_down)
        root.bind("<KeyRelease>", self.key_up)
        root.protocol("WM_DELETE_WINDOW", root.destroy)
        self.new_round()
        self.loop()

    def key_down(self, e):
        key = e.keysym.lower()
        first = key not in self.keys
        self.keys.add(key)
        if first and key == "escape":
            self.paused = not self.paused
        if first and key == "r":
            self.scores = [0, 0]
            self.new_round()
        if first and key == "n" and self.round_over:
            self.new_round()
        if first and key in ("space", "return") and not self.paused and not self.round_over:
            tank = self.tanks[0] if key == "space" else self.tanks[1]
            self.fire(tank)

    def key_up(self, e):
        self.keys.discard(e.keysym.lower())

    def generate_maze(self):
        # Perfect maze first, then open a few extra passages for less predictable fights.
        visited = {(0, 0)}
        stack = [(0, 0)]
        passages = set()
        while stack:
            x, y = stack[-1]
            options = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if 0 <= q[0] < COLS and 0 <= q[1] < ROWS and q not in visited:
                    options.append(q)
            if not options:
                stack.pop()
                continue
            q = random.choice(options)
            passages.add(frozenset(((x, y), q)))
            visited.add(q)
            stack.append(q)
        for _ in range(18):
            x, y = random.randrange(COLS), random.randrange(ROWS)
            dx, dy = random.choice(((1, 0), (0, 1)))
            q = (x + dx, y + dy)
            if q[0] < COLS and q[1] < ROWS:
                passages.add(frozenset(((x, y), q)))

        thick = 8
        walls = [
            (OX, OY, OX + COLS * CELL, OY + thick),
            (OX, OY + ROWS * CELL - thick, OX + COLS * CELL, OY + ROWS * CELL),
            (OX, OY, OX + thick, OY + ROWS * CELL),
            (OX + COLS * CELL - thick, OY, OX + COLS * CELL, OY + ROWS * CELL),
        ]
        for y in range(ROWS):
            for x in range(COLS):
                if x < COLS - 1 and frozenset(((x, y), (x + 1, y))) not in passages:
                    px = OX + (x + 1) * CELL
                    walls.append((px - thick / 2, OY + y * CELL, px + thick / 2, OY + (y + 1) * CELL + thick / 2))
                if y < ROWS - 1 and frozenset(((x, y), (x, y + 1))) not in passages:
                    py = OY + (y + 1) * CELL
                    walls.append((OX + x * CELL, py - thick / 2, OX + (x + 1) * CELL + thick / 2, py + thick / 2))
        return walls

    def cell_center(self, cell):
        return OX + (cell[0] + .5) * CELL, OY + (cell[1] + .5) * CELL

    def new_round(self):
        self.walls = self.generate_maze()
        a = self.cell_center((0, 0))
        b = self.cell_center((COLS - 1, ROWS - 1))
        self.tanks = [
            Tank(*a, 0, "#46e6a7", "绿方", ("w", "s", "a", "d")),
            Tank(*b, math.pi, "#ff5c74", "红方", ("up", "down", "left", "right")),
        ]
        self.bullets = []
        self.round_over = False
        self.paused = False
        self.message = ""

    def circle_hits_wall(self, x, y, r):
        for x1, y1, x2, y2 in self.walls:
            nx, ny = clamp(x, x1, x2), clamp(y, y1, y2)
            if (x - nx) ** 2 + (y - ny) ** 2 < r * r:
                return True
        return False

    def update_tank(self, tank):
        if not tank.alive:
            return
        forward, back, left, right = tank.controls
        turn = (1 if right in self.keys else 0) - (1 if left in self.keys else 0)
        drive = (1 if forward in self.keys else 0) - (1 if back in self.keys else 0)
        if drive:
            tank.angle += turn * 0.047 * (1 if drive > 0 else -1)
        else:
            tank.angle += turn * 0.035
        speed = 2.8 * drive
        nx = tank.x + math.cos(tank.angle) * speed
        ny = tank.y + math.sin(tank.angle) * speed
        if not self.circle_hits_wall(nx, tank.y, TANK_R):
            tank.x = nx
        if not self.circle_hits_wall(tank.x, ny, TANK_R):
            tank.y = ny
        tank.cooldown = max(0, tank.cooldown - 1)

    def fire(self, tank):
        owned = sum(b.owner is tank for b in self.bullets)
        if not tank.alive or tank.cooldown or owned >= 4:
            return
        muzzle = TANK_R + 13
        self.bullets.append(Bullet(tank.x + math.cos(tank.angle) * muzzle,
                                   tank.y + math.sin(tank.angle) * muzzle,
                                   tank.angle, tank))
        tank.cooldown = 18

    def update_bullet(self, b):
        radius = 5
        nx = b.x + b.vx
        ny = b.y + b.vy
        if self.circle_hits_wall(nx, b.y, radius):
            b.vx *= -1
            nx = b.x + b.vx
        if self.circle_hits_wall(b.x, ny, radius):
            b.vy *= -1
            ny = b.y + b.vy
        if self.circle_hits_wall(nx, ny, radius):
            b.vx *= -1
            b.vy *= -1
            nx, ny = b.x + b.vx, b.y + b.vy
        b.x, b.y = nx, ny
        b.life -= 1
        b.grace -= 1
        for i, tank in enumerate(self.tanks):
            if not tank.alive or (tank is b.owner and b.grace > 0):
                continue
            if (b.x - tank.x) ** 2 + (b.y - tank.y) ** 2 <= (TANK_R + radius) ** 2:
                tank.alive = False
                winner = 1 - i
                self.scores[winner] += 1
                self.round_over = True
                self.message = f"{self.tanks[winner].name}获胜！"
                b.life = 0
                break

    def draw_tank(self, t):
        x, y, a = t.x, t.y, t.angle
        if not t.alive:
            for i in range(10):
                ang = i * math.tau / 10
                self.canvas.create_line(x, y, x + math.cos(ang) * 30, y + math.sin(ang) * 30,
                                        fill="#ffb347", width=3)
            return
        self.canvas.create_oval(x - TANK_R, y - TANK_R, x + TANK_R, y + TANK_R,
                                fill=t.color, outline="#0b1016", width=4)
        self.canvas.create_line(x, y, x + math.cos(a) * 29, y + math.sin(a) * 29,
                                fill=t.color, width=10, capstyle=tk.ROUND)
        self.canvas.create_oval(x - 6, y - 6, x + 6, y + 6, fill="#192330", outline="")

    def draw(self):
        c = self.canvas
        c.delete("all")
        c.create_rectangle(OX, OY, OX + COLS * CELL, OY + ROWS * CELL, fill=FIELD, outline="")
        for x in range(OX, OX + COLS * CELL, CELL):
            c.create_line(x, OY, x, OY + ROWS * CELL, fill="#1f2c3a")
        for y in range(OY, OY + ROWS * CELL, CELL):
            c.create_line(OX, y, OX + COLS * CELL, y, fill="#1f2c3a")
        for wall in self.walls:
            c.create_rectangle(*wall, fill=WALL, outline="#879287")
        for b in self.bullets:
            c.create_oval(b.x - 5, b.y - 5, b.x + 5, b.y + 5, fill="#fff3b0", outline="#ffb347", width=2)
        for t in self.tanks:
            self.draw_tank(t)
        c.create_text(28, 31, text="TANK  TURMOIL", fill="#f5f7ef", anchor="w", font=("Consolas", 22, "bold"))
        c.create_text(WIDTH / 2, 29, text=f"{self.scores[0]}   :   {self.scores[1]}", fill="#ffffff", font=("Consolas", 24, "bold"))
        c.create_text(WIDTH - 28, 23, text="绿方  W/S 移动  A/D 转向  空格开火", fill="#46e6a7", anchor="e", font=("Microsoft YaHei UI", 10))
        c.create_text(WIDTH - 28, 45, text="红方  ↑/↓ 移动  ←/→ 转向  回车开火", fill="#ff5c74", anchor="e", font=("Microsoft YaHei UI", 10))
        c.create_text(WIDTH / 2, HEIGHT - 15, text="Esc 暂停  ·  R 重置比分", fill="#8fa1b4", font=("Microsoft YaHei UI", 9))
        if self.paused or self.round_over:
            c.create_rectangle(265, 285, 735, 430, fill="#0b1016", outline="#d9e2d0", width=3)
            title = "游戏暂停" if self.paused else self.message
            sub = "按 Esc 继续" if self.paused else "按 N 开始下一局"
            c.create_text(WIDTH / 2, 335, text=title, fill="#ffffff", font=("Microsoft YaHei UI", 28, "bold"))
            c.create_text(WIDTH / 2, 387, text=sub, fill="#aab8c5", font=("Microsoft YaHei UI", 14))

    def loop(self):
        if not self.paused and not self.round_over:
            for tank in self.tanks:
                self.update_tank(tank)
            for b in self.bullets[:]:
                self.update_bullet(b)
                if b.life <= 0:
                    self.bullets.remove(b)
        self.draw()
        self.root.after(16, self.loop)


if __name__ == "__main__":
    app = tk.Tk()
    Game(app)
    app.mainloop()
