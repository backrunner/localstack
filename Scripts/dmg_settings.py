import os

application = os.path.abspath(defines.get('app', 'build/LocalStack.app'))
format = 'ULFO'
size = None
files = [application]
symlinks = {'Applications': '/Applications'}
background = os.path.abspath('Resources/Brand/DMGBackground.png')
icon = os.path.abspath('Resources/AppIcon.icns')
window_rect = ((180, 160), (720, 480))
icon_locations = {'LocalStack.app': (220, 268), 'Applications': (500, 268)}
icon_size = 88
text_size = 12
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
default_view = 'icon-view'
arrange_by = None
