package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import prefs "../shared/settings"

Settings_Phase :: enum {
	Ready,
	Reading,
	Writing,
}

Settings :: struct {
	value: prefs.Value,
	enabled, error, dirty, headless: bool,
	phase: Settings_Phase,
	op: rgd.Browser_Store_Op,
	namespace: string,
	revision: u64,
}

settings_ready :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	s.value = prefs.DEFAULT
	s.enabled = scrap_int("RSY_PERSIST", len(scrap_param("RSY_TOKEN", "")) == 0 ? 1 : 0) != 0
	name := gd.display_server_get_name(gd.singleton_display_server())
	s.headless = gd.gd_string_to_odin(name) == "headless"
	gd.free_string(name)
	gd.connect_to(
		gd.get_node(self.owner, "UI/Menu/Scroll/Column/Volume/Down"),
		"pressed",
		self.owner,
		"on_volume_down",
	)
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Volume/Up"), "pressed", self.owner, "on_volume_up")
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Shake"), "pressed", self.owner, "on_shake")
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Fullscreen"), "pressed", self.owner, "on_fullscreen")
	if s.enabled {
		when gd.IS_WEB {
			s.namespace = strings.clone(scrap_param("RSY_PROFILE_NAMESPACE", "scrapyard"))
			if rgd.browser_store_read(&s.op, s.namespace, "settings", 4096) {
				s.phase = .Reading
			} else {
				s.error = true
			}
		} else {
			path := scrap_param("RSY_SETTINGS_PATH", "user://replay_settings")
			text := gd.new_string_odin(path)
			exists := gd.file_access_file_exists(text)
			gd.free_string(text)
			if exists {
				bytes, err := rgd.storage_read(path, 4096)
				defer delete(bytes)
				value, ok := prefs.decode(bytes)
				if err == .None && ok {
					s.value = value
				} else {
					s.error = true
				}
			}
		}
	}
	settings_apply(self, true)
	settings_labels(self)
}

settings_apply :: proc(self: ^ReplayScrapyard, startup: bool = false) {
	s := &self.settings[0]
	audio_volume(self, f32(s.value.volume) / 10)
	screen_motion_setting(self)
	when !gd.IS_WEB {
		if startup && !s.headless {
			gd.display_server_window_set_mode(
				gd.singleton_display_server(),
				s.value.fullscreen ? .Window_Mode_Fullscreen : .Window_Mode_Windowed,
				0,
			)
		}
	}
}

settings_labels :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	gd.set_string(
		gd.get_node(self.owner, "UI/Menu/Scroll/Column/Volume/Value"),
		"text",
		fmt.ctprintf("Sound %d%%", int(s.value.volume) * 10),
	)
	gd.set_string(
		gd.get_node(self.owner, "UI/Menu/Scroll/Column/Shake"),
		"text",
		s.value.shake_off ? "Camera motion: off" : "Camera motion: on",
	)
	fullscreen :=
		!s.headless && gd.display_server_window_get_mode(gd.singleton_display_server(), 0) == .Window_Mode_Fullscreen
	gd.set_string(
		gd.get_node(self.owner, "UI/Menu/Scroll/Column/Fullscreen"),
		"text",
		fullscreen ? "Fullscreen: on" : "Fullscreen: off",
	)
	gd.base_button_set_disabled(
		cast(gd.Base_Button)gd.get_node(self.owner, "UI/Menu/Scroll/Column/Fullscreen"),
		s.headless || s.phase == .Reading,
	)
	paths := [?]cstring {
		"UI/Menu/Scroll/Column/Volume/Down",
		"UI/Menu/Scroll/Column/Volume/Up",
		"UI/Menu/Scroll/Column/Shake",
	}
	for path in paths {
		gd.base_button_set_disabled(cast(gd.Base_Button)gd.get_node(self.owner, path), s.phase == .Reading)
	}
	status: cstring = s.enabled ? "" : "Changes apply to this session."
	if s.phase == .Reading {
		status = "Loading settings…"
	} else if s.error {
		status = "Settings could not be saved. Existing data was kept."
	} else if s.phase == .Writing || s.dirty {
		status = "Saving settings…"
	}
	gd.set_string(gd.get_node(self.owner, "UI/Menu/Scroll/Column/SettingsStatus"), "text", status)
}

settings_save :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	if !s.enabled || s.error || !s.dirty || s.phase != .Ready {
		return
	}
	bytes, ok := prefs.encode(s.value)
	defer delete(bytes)
	if !ok {
		s.error = true
		return
	}
	when gd.IS_WEB {
		if rgd.browser_store_write(&s.op, s.namespace, "settings", bytes, s.revision, 4096) {
			s.phase = .Writing
			s.dirty = false
		} else {
			s.error = true
		}
	} else {
		if rgd.storage_write(scrap_param("RSY_SETTINGS_PATH", "user://replay_settings"), bytes, 4096) != .None {
			s.error = true
		} else {
			s.dirty = false
		}
	}
}

settings_poll :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	when gd.IS_WEB {
		if s.phase != .Ready && rgd.browser_store_poll(&s.op) == .Complete {
			if s.phase == .Reading && s.op.error == .Missing {
				s.revision = 0
			} else if s.op.error != .None {
				s.error = true
			} else if s.phase == .Reading {
				bytes, err := rgd.browser_store_bytes(&s.op)
				defer delete(bytes)
				value, ok := prefs.decode(bytes)
				if err != .None || !ok {
					s.error = true
				} else {
					s.value = value
					s.revision = s.op.revision
					settings_apply(self, true)
				}
			} else {
				s.revision = s.op.revision
			}
			rgd.browser_store_close(&s.op)
			s.phase = .Ready
		}
	}
	settings_save(self)
	if self.menu_open {
		settings_labels(self)
	}
}

settings_changed :: proc(self: ^ReplayScrapyard) {
	self.settings[0].dirty = self.settings[0].enabled
	settings_apply(self)
	settings_save(self)
	settings_labels(self)
	audio_direct(self, {kind = .Buy})
}

@(gd_method)
replay_scrapyard_on_volume_down :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	if s.phase == .Reading {
		return
	}
	if s.value.volume > 0 {
		s.value.volume -= 1
	}
	settings_changed(self)
}

@(gd_method)
replay_scrapyard_on_volume_up :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	if s.phase == .Reading {
		return
	}
	if s.value.volume < 10 {
		s.value.volume += 1
	}
	settings_changed(self)
}

@(gd_method)
replay_scrapyard_on_shake :: proc(self: ^ReplayScrapyard) {
	if self.settings[0].phase == .Reading {
		return
	}
	self.settings[0].value.shake_off = !self.settings[0].value.shake_off
	settings_changed(self)
}

@(gd_method)
replay_scrapyard_on_fullscreen :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	if s.headless || s.phase == .Reading {
		return
	}
	s.value.fullscreen = gd.display_server_window_get_mode(gd.singleton_display_server(), 0) != .Window_Mode_Fullscreen
	gd.display_server_window_set_mode(
		gd.singleton_display_server(),
		s.value.fullscreen ? .Window_Mode_Fullscreen : .Window_Mode_Windowed,
		0,
	)
	settings_changed(self)
}

settings_close :: proc(self: ^ReplayScrapyard) {
	s := &self.settings[0]
	rgd.browser_store_close(&s.op)
	delete(s.namespace)
	s^ = {}
}
