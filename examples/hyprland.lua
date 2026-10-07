-- Hyprland 0.55+ (hyprland.lua)
-- Make the notes popup float, centered, at half the monitor width.

hl.window_rule({
	name = "notes-popup",
	match = { class = "^notes-popup$" },
	float = true,
	center = true,
	size = { "monitor_w * 0.5", "monitor_h * 0.6" },
})

-- Keybinding (adjust `mainMod` to your own)
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("$HOME/.local/bin/notes-popup"))
