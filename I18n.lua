-- Plik: workspace/Vanguard/I18n.lua

local I18n = {}

local lang = "pl"
local tabButtons = {}

local STR = {
	pl = {
		tab_visuals = "Visuals",
		tab_legit = "Legit",
		tab_rage = "Rage",
		tab_anim = "Anim",
		tab_world = "World",
		tab_settings = "Settings",
		tab_misc = "Misc",
		tab_menus = "Menus",
		tab_config = "Config",
		tab_music = "Music",
		subtitle_studio = "ESP STUDIO",
		set_interface = "INTERFEJS",
		set_menu_lang = "Język menu",
		set_notify_style = "Styl powiadomień",
		lang_pl = "Polski",
		lang_en = "English",
		notify_pro = "Pro",
		notify_compact = "Kompakt",
		notify_info = "Informacja",
		notify_success = "Sukces",
		notify_error = "Błąd",
		notify_warn = "Uwaga",
		lang_changed = "Język zmieniony — część etykiet zaktualizowana.",
		notify_style_changed = "Styl powiadomień zaktualizowany.",
		music_added_queue = "Dodano do kolejki",
		music_already_queue = "Już w kolejce",
		music_queue_cleared = "Kolejka wyczyszczona",
		music_no_audius = "Brak na Audius: %s — wybierz wiersz ▶ Audius z listy",
		music_audius_fail = "Nie pobrano z Audius — spróbuj ponownie",
		music_pick_track = "Wybierz utwór",
		music_only_you = "tylko Ty słyszysz",
		music_queue_label = "DO ODTWORZENIA",
		music_clear_queue = "Wyczyść",
		music_auto_next = "Auto-next (kolejka)",
		music_mini_player = "Mini player (bez menu)",
		music_playable = "▶ odtwarza",
		music_yt_hint = "YT (szukaj na Audius)",
	},
	en = {
		tab_visuals = "Visuals",
		tab_legit = "Legit",
		tab_rage = "Rage",
		tab_anim = "Anim",
		tab_world = "World",
		tab_settings = "Settings",
		tab_misc = "Misc",
		tab_menus = "Menus",
		tab_config = "Config",
		tab_music = "Music",
		subtitle_studio = "ESP STUDIO",
		set_interface = "INTERFACE",
		set_menu_lang = "Menu language",
		set_notify_style = "Notification style",
		lang_pl = "Polish",
		lang_en = "English",
		notify_pro = "Pro",
		notify_compact = "Compact",
		notify_info = "Notice",
		notify_success = "Success",
		notify_error = "Error",
		notify_warn = "Warning",
		lang_changed = "Language updated — tab labels refreshed.",
		notify_style_changed = "Notification style updated.",
		music_added_queue = "Added to queue",
		music_already_queue = "Already in queue",
		music_queue_cleared = "Queue cleared",
		music_no_audius = "Not on Audius: %s — pick a ▶ Audius row from results",
		music_audius_fail = "Audius download failed — try again",
		music_pick_track = "Pick a track",
		music_only_you = "only you hear this",
		music_queue_label = "UP NEXT",
		music_clear_queue = "Clear",
		music_auto_next = "Auto-next (queue)",
		music_mini_player = "Mini player (no menu)",
		music_playable = "▶ plays",
		music_yt_hint = "YT (search Audius)",
	},
}

function I18n.Init(S)
	local l = tostring(S.MenuLang or "pl"):lower()
	if l ~= "en" then
		l = "pl"
	end
	lang = l
end

function I18n.getLang()
	return lang
end

function I18n.setLang(l)
	l = tostring(l or "pl"):lower()
	if l ~= "en" then
		l = "pl"
	end
	lang = l
end

function I18n.t(key, ...)
	local pack = STR[lang] or STR.pl
	local template = pack[key] or STR.pl[key] or tostring(key)
	if select("#", ...) > 0 then
		return string.format(template, ...)
	end
	return template
end

function I18n.registerTabButton(key, btn)
	tabButtons[key] = btn
end

function I18n.refreshTabs()
	for key, btn in pairs(tabButtons) do
		if btn and btn.Parent then
			btn.Text = "  " .. I18n.t("tab_" .. key)
		end
	end
end

return I18n
