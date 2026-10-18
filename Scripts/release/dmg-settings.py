# Layout of the disk image window, read by dmgbuild (https://dmgbuild.readthedocs.io).
# The icon positions must match the arrow in Scripts/make-dmg-background.swift.
import os

application = defines["app"]  # noqa: F821 - `defines` is provided by dmgbuild
appname = os.path.basename(application)

files = [application]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821

# The window shows 660 x 400 points of the background under a 28 point title bar. The background is
# 420 points tall, so that a thinner title bar crops some empty paper and shows no blank strip.
window_rect = ((200, 140), (660, 428))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 13
label_pos = "bottom"
icon_locations = {
    appname: (165, 232),
    "Applications": (495, 232),
}
