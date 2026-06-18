import sys, os
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtGui import QGuiApplication, QImage, QPainter, QColor
from PyQt6.QtSvg import QSvgRenderer

app = QGuiApplication(sys.argv)
inp, out = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 192
r = QSvgRenderer(inp)
img = QImage(size, size, QImage.Format.Format_ARGB32)
img.fill(QColor("#2b3340"))
p = QPainter(img)
r.render(p)
p.end()
img.save(out)
