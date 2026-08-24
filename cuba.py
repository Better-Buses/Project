import math

hs = 8
ms = 30
for i in range(10):
  t = i * 25

  h = hs + math.floor(t / 60)
  m = ms + t % 60

  print(f"{h:2}:{m:2}:00", end=", ")
print()