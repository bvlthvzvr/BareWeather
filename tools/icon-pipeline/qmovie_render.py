import sys, os
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtGui import QGuiApplication, QImage, QPainter, QColor
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QMovie
app = QGuiApplication(sys.argv)
inp, out = sys.argv[1], sys.argv[2]
frame = int(sys.argv[3]) if len(sys.argv) > 3 else 0
m = QMovie(inp)
m.start()
m.jumpToFrame(frame)
img = m.currentImage()
bg = QImage(img.size(), QImage.Format.Format_ARGB32)
bg.fill(QColor("#2b3340"))
p = QPainter(bg); p.drawImage(0, 0, img); p.end()
bg.save(out)
print("frame", frame, "size", img.width(), img.height())
