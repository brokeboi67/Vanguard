-- Plik: workspace/Vanguard/I18n.lua

local I18n = {}

local lang = "pl"
local tabButtons = {}
local refreshables = {}

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
		lang_changed = "Język zmieniony.",
		notify_style_changed = "Styl powiadomień zaktualizowany.",
		notify_disabled = "Wyłączono: %s",
		notify_disabled_legit = "Wyłączono Legit: %s",
		notify_movement = "Movement: %s",
		notify_movement_err = "Błąd movement pack",
		notify_anim_stopped = "Animacja zatrzymana",
		notify_anim = "Animacja: %s",
		notify_anim_err = "Błąd animacji",
		notify_no_target = "Brak celu",
		notify_kill_fx = "Kill FX na wrogu w crosshair",
		notify_hit_fx = "Hit FX na wrogu w crosshair",
		notify_no_config = "Brak modułu config",
		notify_autoload_fail = "Brak autoload lub błąd wczytywania",
		notify_unloaded = "Vanguard wyładowany — możesz reinject",
		notify_transfer_on = "Transfer ON — działa tylko z queue_on_teleport executora",
		notify_transfer_off = "Transfer wyłączony — kolejka wyczyszczona",
		notify_rejoin_err = "Błąd rejoin",
		notify_hop_err = "Błąd server hop",
		notify_friend_removed = "Usunięto z listy",
		notify_friends_cleared = "Lista znajomych wyczyszczona",
		notify_test_hitmarker = "Test hitmarker / dźwięku",
		notify_features_missing = "Features nie załadowane",
		notify_autoload = "Autoload: %s",
		notify_unload_unavail = "Unload niedostępny",
		notify_rejoin = "Rejoin...",
		notify_rejoin_unavail = "Rejoin niedostępny",
		notify_searching_server = "Szukam serwera...",
		notify_hop_unavail = "Server hop niedostępny",
		notify_disabled_master_rage = "Wyłączono: Master Rage",
		btn_clear_list = "Wyczyść listę",
		btn_autoload_now = "Załaduj autoload teraz",
		friends_empty = "Brak znajomych na liście",
		card_vfilter_desc = "Ukrywanie teammateów i znajomych z ESP.",
		card_vcolors_desc = "Tryby kolorów — wykluczają się nawzajem.",
		card_vadv_desc = "Rainbow / Team Colors / LoS się wykluczają.",
		card_vtrace_desc = "Neonowa linia od broni do celu — tylko Ty widzisz.",
		card_laim_desc = "Aimbot i Silent się wykluczają.",
		card_laimbind_desc = "Kliknij wiersz i naciśnij klawisz lub M1/M2/M3.",
		card_lfov_desc = "Smooth działa tylko z Aimbot (hold keybind).",
		card_rmaster_desc = "Wyłącza wszystkie funkcje Legit.",
		card_raa_desc = "Obrót postaci od kamery + offsety.",
		card_rbot_desc = "Bez FOV — strzela gdy hitbox widoczny z kamery.",
		card_wquick_desc = "Szybkie presety — lokalne, tylko u Ciebie.",
		card_wlight_desc = "Jasność, cienie, ambient i ekspozycja.",
		card_wfog_desc = "Mgła, kolor i gęstość atmosfery.",
		card_wgrade_desc = "ColorCorrection + ColorShift (jak world mod w CS).",
		card_wpost_desc = "Bloom i Sun Rays (jeśli gra ma te efekty).",
		card_aplayback_desc = "Speed/weight działają na emote i local FX. Loop = tańce w kółko.",
		card_amove_desc = "Idle/walk/run/jump — podmiana Animate. Inni widzą nowy styl ruchu.",
		card_aplay_desc = "Najpierw /e (jeśli gra wspiera), potem asset ID z replikacją.",
		card_mmove_desc = "Auto Strafe działa w powietrzu (razem z BHop).",
		card_mhit_desc = "Niewidoczne hitboxy — nie powiększa modelu postaci.",
		card_msec_desc = "gethui + protect_gui + losowe nazwy GUI (bez lagujących hooków).",
		card_mfx_desc = "Tylko Ty widzisz — efekty przy hit / kill.",
		card_sfriend_desc = "Ctrl + Click na gracza — dodaj / usuń z wykluczeń.",
		card_sauto_desc = "Config ładuje się przy starcie skryptu.",
		card_ssession_desc = "Zarządzanie skryptem.",
		hint_vfilter = "Ctrl+Click na gracza dodaje znajomego — ukryty jak teammate (Settings).",
		hint_vcolors = "Custom kolory (V/O) działają tylko gdy wyłączone: Team Colors, LoS i Chams Rainbow.",
		hint_vadv = "Strzałki na krawędzi ekranu — Enhanced = większe, tło, nick i czytelny dystans.",
		hint_vtrace = "Linia od crosshaira przez cel (przebija postać). Kill = grubsza czerwona + kula.",
		hint_ltrig = "Ten sam FOV i TARGETING co aim/silent. Bez Compatibility = strzela bez ruszania kamery. Compatibility = śledzi + strzela (gry z własnym hitregiem).",
		hint_rbot = "Silent = krótki flick + powrót kamery. Track = lock. Snap = celuj i strzelaj. Compatibility = track + strzał dla gier z własnym hitregiem.",
		hint_wquick = "FullBright = bez cieni + jasne Ambient. No Fog = wyłącza mgłę i Atmosphere.",
		hint_wgrade = "Quick Tint działa gdy Custom Grading wyłączone. Włącz Grading dla pełnej kontroli.",
		hint_aplayback = "✦ = inni widzą (replikowane)   ·   ◎ = tylko u Ciebie (local FX). Rig: %s.",
		hint_aplay = "Wave/Point/Laugh = jednorazowe. Wyłącz Loop dla pozostałych emote.",
		hint_mhit1 = "Powiększa hitboxy lokalnie dla aim/trigger (folder VG_Hitboxes). Nie zmienia serwera.",
		hint_mhit2 = "Domyślnie pomija teammateów i znajomych (zgodnie z Exclude Team).",
		hint_msec = "267 = gra wykrywa skrypt/executor. Używaj gethui i nie ładuj 2 cheatów naraz.",
		hint_mfx = "Hit FX = od razu przy strzale cheata. Kill FX = przy śmierci wroga. Test = cel w crosshair.",
		hint_shud1 = "Hitmarker: krzyżyk na środku ekranu po trafieniu (1.5s od strzału). Damage log pokazuje -HP.",
		hint_shud2 = "Spectator list pokazuje tylko graczy, którzy faktycznie Cię obserwują (atrybuty / kamera).",
		hint_ssession1 = "Transfer: wymaga queue_on_teleport. Blokuje inne gry (GameId). Teleport w grze = autoload. Inject ręczny = bez autoload przy wyjściu.",
		hint_ssession2 = "Unload usuwa menu, HUD i hooki. Po reinject menu załaduje się od nowa.",
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
		music_loading = "Ładowanie...",
		music_downloading = "Pobieranie utworu...",
		music_pause = "Pauza",
		music_search_ph = "Szukaj utworów...",
		music_search_btn = "Szukaj",
		music_status_auto = "Auto — szuka YT+Audius, odtwarza z Audius",
		music_status_source = "Źródło: %s",
		music_src_auto = "Auto (Audius + YT podgląd)",
		music_src_audius = "Audius · odtwarza",
		music_src_youtube = "YouTube · tylko szukaj",
		music_src_archive = "Archive.org",
		music_searching = "Szukam...",
		music_search_timeout = "Timeout — szczegóły w konsoli (F9)",
		music_no_module = "Błąd: brak modułu Music",
		music_results = "%d wyników%s",
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
		lang_changed = "Language updated.",
		notify_style_changed = "Notification style updated.",
		notify_disabled = "Disabled: %s",
		notify_disabled_legit = "Disabled Legit: %s",
		notify_movement = "Movement: %s",
		notify_movement_err = "Movement pack error",
		notify_anim_stopped = "Animation stopped",
		notify_anim = "Animation: %s",
		notify_anim_err = "Animation error",
		notify_no_target = "No target",
		notify_kill_fx = "Kill FX on crosshair enemy",
		notify_hit_fx = "Hit FX on crosshair enemy",
		notify_no_config = "Config module missing",
		notify_autoload_fail = "No autoload or load error",
		notify_unloaded = "Vanguard unloaded — you can reinject",
		notify_transfer_on = "Transfer ON — requires executor queue_on_teleport",
		notify_transfer_off = "Transfer off — queue cleared",
		notify_rejoin_err = "Rejoin error",
		notify_hop_err = "Server hop error",
		notify_friend_removed = "Removed from list",
		notify_friends_cleared = "Friend list cleared",
		notify_test_hitmarker = "Hitmarker / sound test",
		notify_features_missing = "Features not loaded",
		notify_autoload = "Autoload: %s",
		notify_unload_unavail = "Unload unavailable",
		notify_rejoin = "Rejoin...",
		notify_rejoin_unavail = "Rejoin unavailable",
		notify_searching_server = "Searching for server...",
		notify_hop_unavail = "Server hop unavailable",
		notify_disabled_master_rage = "Disabled: Master Rage",
		btn_clear_list = "Clear list",
		btn_autoload_now = "Load autoload now",
		friends_empty = "No friends on list",
		card_vfilter_desc = "Hide teammates and friends from ESP.",
		card_vcolors_desc = "Color modes — mutually exclusive.",
		card_vadv_desc = "Rainbow / Team Colors / LoS are mutually exclusive.",
		card_vtrace_desc = "Neon line from gun to target — only you see it.",
		card_laim_desc = "Aimbot and Silent are mutually exclusive.",
		card_laimbind_desc = "Click a row and press a key or M1/M2/M3.",
		card_lfov_desc = "Smooth works only with Aimbot (hold keybind).",
		card_rmaster_desc = "Disables all Legit features.",
		card_raa_desc = "Rotate character away from camera + offsets.",
		card_rbot_desc = "No FOV — fires when hitbox is visible from camera.",
		card_wquick_desc = "Quick presets — local, only for you.",
		card_wlight_desc = "Brightness, shadows, ambient and exposure.",
		card_wfog_desc = "Fog, color and atmosphere density.",
		card_wgrade_desc = "ColorCorrection + ColorShift (like CS world mod).",
		card_wpost_desc = "Bloom and Sun Rays (if the game supports them).",
		card_aplayback_desc = "Speed/weight apply to emotes and local FX. Loop = dance on repeat.",
		card_amove_desc = "Idle/walk/run/jump — replaces Animate. Others see the new movement style.",
		card_aplay_desc = "First /e (if the game supports it), then replicated asset ID.",
		card_mmove_desc = "Auto Strafe works in the air (with BHop).",
		card_mhit_desc = "Invisible hitboxes — does not enlarge the character model.",
		card_msec_desc = "gethui + protect_gui + random GUI names (no laggy hooks).",
		card_mfx_desc = "Only you see — effects on hit / kill.",
		card_sfriend_desc = "Ctrl + Click a player — add / remove from exclusions.",
		card_sauto_desc = "Config loads when the script starts.",
		card_ssession_desc = "Script session management.",
		hint_vfilter = "Ctrl+Click a player adds a friend — hidden like a teammate (Settings).",
		hint_vcolors = "Custom colors (V/O) work only when disabled: Team Colors, LoS and Chams Rainbow.",
		hint_vadv = "Edge-of-screen arrows — Enhanced = larger, background, name and readable distance.",
		hint_vtrace = "Line from crosshair through target (pierces character). Kill = thicker red + sphere.",
		hint_ltrig = "Same FOV and TARGETING as aim/silent. Without Compatibility = shoot without moving camera. Compatibility = track + shoot (games with custom hitreg).",
		hint_rbot = "Silent = short flick + camera return. Track = lock. Snap = aim and shoot. Compatibility = track + shot for games with custom hitreg.",
		hint_wquick = "FullBright = no shadows + bright Ambient. No Fog = disables fog and Atmosphere.",
		hint_wgrade = "Quick Tint works when Custom Grading is off. Enable Grading for full control.",
		hint_aplayback = "✦ = others see (replicated)   ·   ◎ = local only. Rig: %s.",
		hint_aplay = "Wave/Point/Laugh = one-shot. Disable Loop for other emotes.",
		hint_mhit1 = "Enlarges hitboxes locally for aim/trigger (VG_Hitboxes folder). Does not change the server.",
		hint_mhit2 = "By default skips teammates and friends (per Exclude Team).",
		hint_msec = "267 = game detects script/executor. Use gethui and do not load 2 cheats at once.",
		hint_mfx = "Hit FX = immediately on cheat shot. Kill FX = on enemy death. Test = crosshair target.",
		hint_shud1 = "Hitmarker: crosshair on screen center after hit (1.5s from shot). Damage log shows -HP.",
		hint_shud2 = "Spectator list shows only players actually spectating you (attributes / camera).",
		hint_ssession1 = "Transfer: requires queue_on_teleport. Blocks other games (GameId). In-game teleport = autoload. Manual inject = no autoload on leave.",
		hint_ssession2 = "Unload removes menu, HUD and hooks. After reinject the menu loads fresh.",
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
		music_loading = "Loading...",
		music_downloading = "Downloading track...",
		music_pause = "Paused",
		music_search_ph = "Search tracks...",
		music_search_btn = "Search",
		music_status_auto = "Auto — searches YT+Audius, plays from Audius",
		music_status_source = "Source: %s",
		music_src_auto = "Auto (Audius + YT preview)",
		music_src_audius = "Audius · plays",
		music_src_youtube = "YouTube · search only",
		music_src_archive = "Archive.org",
		music_searching = "Searching...",
		music_search_timeout = "Timeout — see console (F9)",
		music_no_module = "Error: Music module missing",
		music_results = "%d results%s",
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

function I18n.registerText(label, key, argsFn, prop)
	table.insert(refreshables, { label = label, key = key, argsFn = argsFn, prop = prop or "Text" })
end

local function refreshOne(item)
	if not item.label or not item.label.Parent then
		return
	end
	local prop = item.prop or "Text"
	local text
	if item.argsFn then
		local a = item.argsFn()
		if type(a) == "table" then
			text = I18n.t(item.key, table.unpack(a))
		else
			text = I18n.t(item.key, a)
		end
	else
		text = I18n.t(item.key)
	end
	item.label[prop] = text
end

function I18n.refreshTabs()
	for key, btn in pairs(tabButtons) do
		if btn and btn.Parent then
			btn.Text = "  " .. I18n.t("tab_" .. key)
		end
	end
end

function I18n.refreshAll()
	I18n.refreshTabs()
	for _, item in ipairs(refreshables) do
		refreshOne(item)
	end
end

return I18n
