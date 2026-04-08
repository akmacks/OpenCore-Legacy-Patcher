import sys, os, types, logging
logging.basicConfig(level=logging.INFO, format='%(message)s')
REPO = "/Users/akmacks/OpenCore-Legacy-Patcher"
sys.path.insert(0, REPO)
sys.path.insert(0, '/Users/akmacks/Library/Python/3.14/lib/python/site-packages')
for mod in ['wx','wx.html2','wx.adv','applescript','markdown2','macos_pkg_builder','mac_signing_buddy']:
    m = types.ModuleType(mod); m.__path__ = []; sys.modules[mod] = m
wx = sys.modules['wx']
for a in ['Frame','App','Panel','Dialog','StaticText','Button','BoxSizer','VERTICAL','HORIZONTAL','EXPAND','ALL','ALIGN_CENTRE','ALIGN_RIGHT','OK','ICON_EXCLAMATION','YES_NO','YES_DEFAULT','ICON_INFORMATION','ID_YES','ID_CANCEL','STAY_ON_TOP','DEFAULT_FRAME_STYLE','RESIZE_BORDER','MAXIMIZE_BOX','BITMAP_TYPE_ICON','FONTWEIGHT_BOLD','FONTWEIGHT_NORMAL','BORDER_SUNKEN','NewId','CallAfter','EVT_BUTTON','BITMAP_TYPE_ANY','NullBitmap']:
    setattr(wx, a, 0)
wx.Bitmap = lambda *a,**k: None; wx.Font = lambda *a,**k: None; wx.Colour = lambda *a,**k: None
wx.html2 = sys.modules['wx.html2']; wx.adv = sys.modules['wx.adv']
import types as _t
wx_gui = _t.ModuleType('opencore_legacy_patcher.wx_gui'); wx_gui.__path__ = []
sys.modules['opencore_legacy_patcher.wx_gui'] = wx_gui
for s in ['gui_entry','gui_main_menu','gui_build','gui_settings','gui_support','gui_help','gui_sys_patch_display','gui_sys_patch_start','gui_update','gui_install_oc','gui_macos_installer_download','gui_about','gui_download','gui_cache_os_update']:
    m2 = _t.ModuleType(f'opencore_legacy_patcher.wx_gui.{s}'); sys.modules[f'opencore_legacy_patcher.wx_gui.{s}'] = m2; setattr(wx_gui, s, m2)
app_entry = _t.ModuleType('opencore_legacy_patcher.application_entry')
app_entry.main = lambda: None; app_entry.OpenCoreLegacyPatcher = object
sys.modules['opencore_legacy_patcher.application_entry'] = app_entry
ap = _t.ModuleType('opencore_legacy_patcher.sys_patch.auto_patcher'); ap.__path__ = []
ap.InstallAutomaticPatchingServices = lambda *a,**k: None
sys.modules['opencore_legacy_patcher.sys_patch.auto_patcher'] = ap
for s in ['start','install']:
    m3 = _t.ModuleType(f'opencore_legacy_patcher.sys_patch.auto_patcher.{s}')
    setattr(m3, 'StartAutomaticPatching', type('X', (), {'__init__': lambda s,*a,**k: None, 'start_auto_patch': lambda s: None}))
    setattr(m3, 'InstallAutomaticPatchingServices', lambda *a,**k: None)
    sys.modules[f'opencore_legacy_patcher.sys_patch.auto_patcher.{s}'] = m3; setattr(ap, s, m3)
from opencore_legacy_patcher import constants
from opencore_legacy_patcher.support import defaults
from opencore_legacy_patcher.detections import device_probe, os_probe
from opencore_legacy_patcher.sys_patch import sys_patch
c = constants.Constants(); c.wxpython_variant = False; c.cli_mode = True; c.gui_mode = False; c.is_patching_external_volume = False
o = os_probe.OSProbe()
c.detected_os = o.detect_kernel_major(); c.detected_os_minor = o.detect_kernel_minor()
c.detected_os_build = o.detect_os_build(); c.detected_os_version = o.detect_os_version()
c.computer = device_probe.Computer.probe(); c.custom_model = "Macmini5,3"
defaults.GenerateDefaults(c.custom_model, False, c)
print(f"OS: {c.detected_os_version} ({c.detected_os_build}) Darwin {c.detected_os}")
print(f"Model: {c.custom_model}")
print("Starting root patch...")
sys_patch.PatchSysVolume(c.custom_model, c, None).start_patch()
