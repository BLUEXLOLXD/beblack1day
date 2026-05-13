local create = loadstring(
	game:HttpGet(
		"https://raw.githubusercontent.com/charlesle-clerc/RRenhancements/refs/heads/main/utilities/library.luau"
	)
)()

--// App bootstrap
local app = create({
	game_key = "project_apex",
	game_file = "games/project_apex.luau",
	version = "v1",
	tabs = {
		{ id = "grav", name = "Gravity" },
		{ id = "a_chassis", name = "A-Chassis" },
		{ id = "corner_cuts", name = "Corner Cuts" },
		{ id = "pit_system", name = "Pit System" },
		{ id = "lap_system", name = "Lap System" },
		{ id = "economy", name = "Economy" },
		{ id = "ui_settings", name = "UI & Info" },
	},
})

local grav = app.tabs.grav
local a_tab = app.tabs.a_chassis
local c_tab = app.tabs.corner_cuts
local p_tab = app.tabs.pit_system
local l_tab = app.tabs.lap_system
local e_tab = app.tabs.economy

local players = game:GetService("Players")
local reps = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local run_service = game:GetService("RunService")
local lp = players.LocalPlayer

--// Shared helpers
local function is_num_obj(x)
	return x and (x:IsA("NumberValue") or x:IsA("IntValue"))
end

local function bind_changed(ctrl, setter)
	ctrl:OnChanged(function(v)
		local ok, err = pcall(setter, v)
		if not ok then
			warn("rre: OnChanged callback error: " .. tostring(err))
		end
	end)
end

local function bind_many(defs)
	for _, item in ipairs(defs) do
		bind_changed(item.ctrl, item.set)
	end
end

local function clone_value(v)
	if type(v) == "table" then
		return table.clone(v)
	end
	return v
end

local function destroy_named(parent, name)
	if not parent then
		return
	end

	for _, x in ipairs(parent:GetChildren()) do
		if x.Name == name then
			x:Destroy()
		end
	end
end

local function to_nonneg_number(value)
	local n = tonumber(value)
	if not n then
		return nil
	end
	return math.max(0, n)
end

--// =========================
--// A-Chassis
--// =========================
local a_box = {
	main = a_tab:AddLeftGroupbox("Tune"),
	rt = a_tab:AddLeftGroupbox("Runtime"),
	drs = a_tab:AddRightGroupbox("DRS"),
	no_dmg = a_tab:AddRightGroupbox("No Damage"),
	tyres = a_tab:AddRightGroupbox("Tyres"),
}

local a_state = {
	enabled = false,
	nd_fx = false,
	nd_vis = false,
	no_deg = false,
	deg_delay = 4,
	force_drs = false,
	df_lock = false,
	df_f = 545,
	df_r = 670,
	df_drag = 66.1,
	global_drs_lock = false,
	global_drs = false,
}

local a_tune = {
	FCamber = -2.5,
	RCamber = -1.5,
	FToe = 0.1,
	RToe = 0.1,
	Weight = 2080,
	WeightDist = 55,
	CGHeight = 0.45,
	FWheelDensity = 0.25,
	RWheelDensity = 0.4,
	FSusStiffness = 35000,
	FSusDamping = 1100,
	FPreCompress = 0.35,
	FGyroDampening = 130,
	RSusStiffness = 35000,
	RSusDamping = 1150,
	RPreCompress = 0.35,
	RGyroDampening = 130,
	FSusAngle = 75,
	RSusAngle = 75,
	FGyroDamp = 120,
	RGyroDamp = 120,
	SteerRatio = 13,
	Ackerman = 0.9,
	SteerInner = 34,
	SteerOuter = 32,
	SteerSpeed = 0.13,
	ReturnSpeed = 0.15,
	SteerDecay = 500,
	ThrotAccel = 0.06,
	ThrotDecel = 0.7,
	RDiffSlipThres = 65,
	RDiffLockThres = 35,
	RDiffPower = 90,
	RDiffCoast = 45,
	RDiffPreload = 25,
	TCSEnabled = true,
	TCSThreshold = 18,
	TCSGradient = 18,
	BrakeForce = 13500,
	BrakeBias = 0.7,
	Ratios = { 20, 0, 14.077, 9.45, 8.82, 7.29, 6.21, 5.31, 4.68, 4.14 },
	Horsepower = 570,
	E_Torque = 343,
	T_Boost = 16.8,
}

local function apply_tune(car)
	if not a_state.enabled then
		return
	end
	if not car then
		return
	end

	local tune_mod = car:FindFirstChild("A-Chassis Tune") or car:WaitForChild("A-Chassis Tune", 5)
	if not tune_mod then
		return
	end

	local ok, tune = pcall(require, tune_mod)
	if not ok or type(tune) ~= "table" then
		return
	end

	for key, value in pairs(a_tune) do
		tune[key] = clone_value(value)
	end
end

local ui_car_cache = {
	stamp = 0,
	car = nil,
}

local function resolve_ui_car()
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end

	local ui = pg:FindFirstChild("A-Chassis Interface")
	if not ui then
		return nil
	end

	local car = ui:FindFirstChild("Car")
	if not car or not car:IsA("ObjectValue") then
		return nil
	end

	if car.Value and car.Value:IsA("Model") then
		return car.Value
	end

	return nil
end

-- Hot path helper used by multiple periodic systems. Cache for a short window.
local function get_ui_car(force_refresh)
	local now = os.clock()
	if force_refresh then
		ui_car_cache.stamp = 0
	end

	if now - ui_car_cache.stamp < 0.05 then
		return ui_car_cache.car
	end

	ui_car_cache.stamp = now
	ui_car_cache.car = resolve_ui_car()
	return ui_car_cache.car
end

local function clear_dmg(car)
	local info = car and car:FindFirstChild("Information")
	local dmg = info and info:FindFirstChild("Damaged")
	if dmg and dmg:IsA("BoolValue") and dmg.Value then
		dmg.Value = false
	end
end

local function clone_tune(src)
	local out = {}
	for k, v in pairs(src) do
		out[k] = clone_value(v)
	end
	return out
end

local a_prof = {}
local a_prof_key = nil

local function car_key(car)
	if not car then
		return nil
	end

	local info = car:FindFirstChild("Information")
	local era = info and info:FindFirstChild("Era")
	local era_v = ""
	if era then
		if era:IsA("StringValue") then
			era_v = era.Value
		elseif era:IsA("NumberValue") or era:IsA("IntValue") then
			era_v = tostring(era.Value)
		end
	end

	if era_v ~= "" then
		return era_v .. "|" .. car.Name
	end
	return car.Name
end

local function save_prof(key)
	if not key then
		return
	end
	a_prof[key] = clone_tune(a_tune)
end

local function load_prof(key)
	local t = key and a_prof[key]
	if not t then
		return false
	end
	for k in pairs(a_tune) do
		a_tune[k] = clone_value(t[k])
	end
	return true
end

local function block_sig(sig)
	if not sig then
		return
	end
	if type(getconnections) ~= "function" then
		return
	end

	for _, conn in ipairs(getconnections(sig)) do
		if conn.Disable then
			conn:Disable()
		elseif conn.Disconnect then
			conn:Disconnect()
		end
	end
end

local function block_dmg_remotes(car)
	if not a_state.nd_vis then
		return
	end

	local seat = car and car:FindFirstChild("DriveSeat")
	if not seat then
		return
	end

	local nose = seat:FindFirstChild("NoseDamage")
	local rw = seat:FindFirstChild("RWDamage")

	if nose then
		block_sig(nose.OnClientEvent)
	end
	if rw then
		block_sig(rw.OnClientEvent)
	end
end

local function clear_dmg_remotes(car)
	local seat = car and car:FindFirstChild("DriveSeat")
	if not seat then
		return
	end

	local fw = seat:FindFirstChild("FWDamage")

	if fw then
		firesignal(fw.OnClientEvent, false)
	end
end

local function refresh_tyres(car)
	local ev = car and car:FindFirstChild("PitEvent")
	if ev then
		firesignal(ev.OnClientEvent)
	end
end

local nd_all_t = 0
local function nd_tick()
	local car = get_ui_car()
	if car then
		if a_state.nd_vis then
			block_dmg_remotes(car)
		end
		if a_state.nd_fx then
			clear_dmg(car)
			clear_dmg_remotes(car)
		end
		return
	end

	if not a_state.nd_fx then
		return
	end
	if os.clock() - nd_all_t < 1 then
		return
	end
	nd_all_t = os.clock()

	local vs = ws:FindFirstChild("Vehicles")
	if not vs then
		return
	end

	for _, v in ipairs(vs:GetChildren()) do
		clear_dmg(v)
		clear_dmg_remotes(v)
	end
end

local function get_global_drs_value()
	local values = reps:FindFirstChild("Values")
	local drs = values and values:FindFirstChild("DRS")
	if drs and drs:IsA("BoolValue") then
		return drs
	end
	return nil
end

local function rt_tick()
	if a_state.global_drs_lock then
		local gdrs = get_global_drs_value()
		if gdrs then
			gdrs.Value = a_state.global_drs
		end
	end

	local car = get_ui_car()
	local info = car and car:FindFirstChild("Information") or nil
	if not info then
		return
	end

	if a_state.force_drs then
		local drs = info:FindFirstChild("DRS")
		if drs and drs:IsA("BoolValue") and not drs.Value then
			drs.Value = true
		end
	end

	if a_state.df_lock then
		local down = info:FindFirstChild("DownforceInfo")
		local f = down and down:FindFirstChild("FDownforce")
		local r = down and down:FindFirstChild("RDownforce")
		local d = down and down:FindFirstChild("Drag")
		local eps = 0.01

		if f and f:IsA("NumberValue") then
			local tgt = math.clamp(a_state.df_f, 0, 2000)
			if math.abs(f.Value - tgt) > eps then
				f.Value = tgt
			end
		end
		if r and r:IsA("NumberValue") then
			local tgt = math.clamp(a_state.df_r, 0, 2000)
			if math.abs(r.Value - tgt) > eps then
				r.Value = tgt
			end
		end
		if d and d:IsA("NumberValue") then
			local tgt = math.clamp(a_state.df_drag, 0, 300)
			if math.abs(d.Value - tgt) > eps then
				d.Value = tgt
			end
		end
	end
end

local a_enabled = a_box.main:AddToggle("ach_enabled", {
	Text = "Enabled",
	Default = false,
})

local a_nd_fx = a_box.no_dmg:AddToggle("ach_nd_fx", {
	Text = "No Damage Effects",
	Default = false,
})

local a_nd_vis = a_box.no_dmg:AddToggle("ach_nd_vis", {
	Text = "No Damage Visuals",
	Default = false,
})

a_box.no_dmg:AddButton({
	Text = "Repair Now",
	Func = function()
		local car = get_ui_car()
		if car then
			clear_dmg(car)
			clear_dmg_remotes(car)
		end
	end,
})

local function get_info(car)
	return car and car:FindFirstChild("Information") or nil
end

local function cap_rt()
	local car = get_ui_car()
	local info = get_info(car)
	if not info then
		return
	end

	local down = info:FindFirstChild("DownforceInfo")
	local f = down and down:FindFirstChild("FDownforce")
	local r = down and down:FindFirstChild("RDownforce")
	local d = down and down:FindFirstChild("Drag")
	if f and f:IsA("NumberValue") then
		a_state.df_f = f.Value
	end
	if r and r:IsA("NumberValue") then
		a_state.df_r = r.Value
	end
	if d and d:IsA("NumberValue") then
		a_state.df_drag = d.Value
	end
end

local rt_drs = a_box.drs:AddToggle("ach_rt_drs", {
	Text = "Force DRS",
	Default = false,
})

local a_global_drs_lock = a_box.drs:AddToggle("ach_global_drs_lock", {
	Text = "Global DRS Lock",
	Default = a_state.global_drs_lock,
})

local a_global_drs = a_box.drs:AddToggle("ach_global_drs", {
	Text = "Global DRS Enabled",
	Default = a_state.global_drs,
})

a_box.drs:AddButton({
	Text = "Read Global DRS",
	Func = function()
		local gdrs = get_global_drs_value()
		if gdrs then
			a_state.global_drs = gdrs.Value
			if a_global_drs and a_global_drs.SetValue then
				pcall(a_global_drs.SetValue, a_global_drs, a_state.global_drs)
			end
		end
	end,
})

local rt_df_on = a_box.rt:AddToggle("ach_rt_df_on", {
	Text = "Downforce Lock",
	Default = false,
})

local rt_df_f = a_box.rt:AddSlider("ach_rt_df_f", {
	Text = "Front Downforce",
	Default = a_state.df_f,
	Min = 0,
	Max = 2000,
	Rounding = 0,
})

local rt_df_r = a_box.rt:AddSlider("ach_rt_df_r", {
	Text = "Rear Downforce",
	Default = a_state.df_r,
	Min = 0,
	Max = 2000,
	Rounding = 0,
})

local rt_df_drag = a_box.rt:AddSlider("ach_rt_df_drag", {
	Text = "Drag",
	Default = a_state.df_drag,
	Min = 0,
	Max = 300,
	Rounding = 2,
})

a_box.rt:AddButton({
	Text = "Read Current Runtime",
	Func = function()
		cap_rt()
		if rt_df_f and rt_df_f.SetValue then
			pcall(rt_df_f.SetValue, rt_df_f, a_state.df_f)
		end
		if rt_df_r and rt_df_r.SetValue then
			pcall(rt_df_r.SetValue, rt_df_r, a_state.df_r)
		end
		if rt_df_drag and rt_df_drag.SetValue then
			pcall(rt_df_drag.SetValue, rt_df_drag, a_state.df_drag)
		end
	end,
})

local a_slider_defs = {
	{ name = "Horsepower", key = "Horsepower", min = 300, max = 900, round = 0 },
	{ name = "E-Torque", key = "E_Torque", min = 100, max = 700, round = 0 },
	{ name = "Turbo Boost", key = "T_Boost", min = 0, max = 30, round = 1 },
	{ name = "Weight", key = "Weight", min = 1800, max = 2600, round = 0 },
	{ name = "Weight Dist", key = "WeightDist", min = 40, max = 65, round = 0 },
	{ name = "Brake Force", key = "BrakeForce", min = 6000, max = 20000, round = 0 },
	{ name = "Brake Bias", key = "BrakeBias", min = 0.4, max = 0.9, round = 2 },
	{ name = "Throttle Accel", key = "ThrotAccel", min = 0.01, max = 0.2, round = 2 },
	{ name = "Throttle Decel", key = "ThrotDecel", min = 0.1, max = 1.2, round = 2 },
	{ name = "R Diff Power", key = "RDiffPower", min = 0, max = 100, round = 0 },
	{ name = "R Diff Coast", key = "RDiffCoast", min = 0, max = 100, round = 0 },
}

local a_pick_values = {}
local a_def_by_name = {}
for _, def in ipairs(a_slider_defs) do
	table.insert(a_pick_values, def.name)
	a_def_by_name[def.name] = def
end

local function call_ctrl(ctrl, name, ...)
	local fn = ctrl and ctrl[name]
	if type(fn) == "function" then
		pcall(fn, ctrl, ...)
	end
end

local function clamp_def(def, value)
	return math.clamp(value, def.min, def.max)
end

local a_pick_name = a_pick_values[1]
local a_pick_def = a_def_by_name[a_pick_name]
local a_pick = a_box.main:AddDropdown("ach_pick", {
	Text = "Tune Key",
	Values = a_pick_values,
	Default = a_pick_name,
	Searchable = true,
})

local a_value = a_box.main:AddSlider("ach_value", {
	Text = "Value",
	Default = a_tune[a_pick_def.key],
	Min = a_pick_def.min,
	Max = a_pick_def.max,
	Rounding = a_pick_def.round,
})

local a_info = a_box.main:AddLabel("")

a_box.main:AddInput("ach_value_input", {
	Text = "Set Value",
	Default = "",
	Placeholder = "Exact value for selected key",
	Callback = function(value)
		local def = a_def_by_name[a_pick_name]
		local n = tonumber(value)
		if not def or not n then
			return
		end

		local next_v = clamp_def(def, n)
		a_tune[def.key] = next_v
		call_ctrl(a_value, "SetValue", next_v)
		if a_prof_key then
			save_prof(a_prof_key)
		end
	end,
})

local function sync_slider()
	local def = a_def_by_name[a_pick_name]
	if not def then
		return
	end

	local current = clamp_def(def, a_tune[def.key] or def.min)
	a_tune[def.key] = current

	call_ctrl(a_value, "SetMin", def.min)
	call_ctrl(a_value, "SetMax", def.max)
	call_ctrl(a_value, "SetRounding", def.round)
	call_ctrl(a_value, "SetValue", current)
	call_ctrl(a_value, "SetText", "Value")

	if a_info and a_info.SetText then
		pcall(a_info.SetText, a_info, string.format("%s (%s - %s)", def.name, tostring(def.min), tostring(def.max)))
	end
end

bind_changed(a_pick, function(v)
	a_pick_name = v
	sync_slider()
end)

bind_changed(a_value, function(v)
	local def = a_def_by_name[a_pick_name]
	if not def then
		return
	end

	local next_v = clamp_def(def, v)
	a_tune[def.key] = next_v
	if next_v ~= v then
		call_ctrl(a_value, "SetValue", next_v)
	end

	if a_prof_key then
		save_prof(a_prof_key)
	end
end)

bind_many({
	{
		ctrl = rt_drs,
		set = function(v)
			a_state.force_drs = v
		end,
	},
	{
		ctrl = a_global_drs_lock,
		set = function(v)
			a_state.global_drs_lock = v
			rt_tick()
		end,
	},
	{
		ctrl = a_global_drs,
		set = function(v)
			a_state.global_drs = v
			rt_tick()
		end,
	},
	{
		ctrl = rt_df_on,
		set = function(v)
			a_state.df_lock = v
			if v then
				cap_rt()
				call_ctrl(rt_df_f, "SetValue", a_state.df_f)
				call_ctrl(rt_df_r, "SetValue", a_state.df_r)
				call_ctrl(rt_df_drag, "SetValue", a_state.df_drag)
			end
		end,
	},
	{
		ctrl = rt_df_f,
		set = function(v)
			a_state.df_f = v
		end,
	},
	{
		ctrl = rt_df_r,
		set = function(v)
			a_state.df_r = v
		end,
	},
	{
		ctrl = rt_df_drag,
		set = function(v)
			a_state.df_drag = v
		end,
	},
})

local wt_defs = {
	{ name = "F Target Friction", key = "FTargetFriction", min = 0.5, max = 3, round = 2 },
	{ name = "R Target Friction", key = "RTargetFriction", min = 0.5, max = 3, round = 2 },
	{ name = "F Wear Speed", key = "FWearSpeed", min = 0, max = 5, round = 2 },
	{ name = "R Wear Speed", key = "RWearSpeed", min = 0, max = 5, round = 2 },
}

local wt_by_name = {}
local wt_val_names = {}
for _, def in ipairs(wt_defs) do
	wt_by_name[def.name] = def
	table.insert(wt_val_names, def.name)
end

local wt_car_vals = {}
local vs_boot = ws:FindFirstChild("Vehicles")
if vs_boot then
	for _, x in ipairs(vs_boot:GetChildren()) do
		if x:IsA("Model") then
			table.insert(wt_car_vals, x.Name)
		end
	end
end

table.sort(wt_car_vals)
if #wt_car_vals == 0 then
	wt_car_vals = { "---" }
end
local wt_car_now = wt_car_vals[1] or "---"
local wt_tyre_vals = { "---" }
local wt_tyre_now = wt_tyre_vals[1]
local wt_val_now = wt_val_names[1]

local wt_car = a_box.tyres:AddDropdown("ach_wt_car", {
	Text = "Car",
	Values = wt_car_vals,
	Default = wt_car_now,
})

local wt_tyre = a_box.tyres:AddDropdown("ach_wt_tyre", {
	Text = "Tyre",
	Values = wt_tyre_vals,
	Default = wt_tyre_now,
})

local wt_val = a_box.tyres:AddDropdown("ach_wt_val", {
	Text = "Tyre Value",
	Values = wt_val_names,
	Default = wt_val_now,
})

local wt_slider = a_box.tyres:AddSlider("ach_wt_slider", {
	Text = "Tyre Number",
	Default = 1,
	Min = 0,
	Max = 5,
	Rounding = 2,
})

local wt_no_deg = a_box.tyres:AddToggle("ach_wt_no_deg", {
	Text = "No Tyre Degradation",
	Default = false,
})

local wt_delay = a_box.tyres:AddSlider("ach_wt_no_deg_delay", {
	Text = "Refresh Delay (s)",
	Default = a_state.deg_delay,
	Min = 1,
	Max = 15,
	Rounding = 1,
})

a_box.tyres:AddButton({
	Text = "Refresh Tyres Now",
	Func = function()
		local car = get_ui_car()
		if car then
			refresh_tyres(car)
		end
	end,
})

local wt_root = reps:FindFirstChild("WheelTune")

local function get_rt_car()
	return get_ui_car()
end

local function get_rt_era()
	local car = get_rt_car()
	local info = car and car:FindFirstChild("Information")
	local era = info and info:FindFirstChild("Era")
	if not era then
		return nil
	end

	if era:IsA("StringValue") and era.Value ~= "" then
		return era.Value
	end
	if era:IsA("IntValue") or era:IsA("NumberValue") then
		return tostring(era.Value)
	end

	return nil
end

local function get_rt_tyre()
	local car = get_rt_car()
	if not car then
		return nil
	end

	local info = car:FindFirstChild("Information")
	if not info then
		return nil
	end

	local wheel = info:FindFirstChild("WheelInfo")
	if wheel and wheel:IsA("Folder") then
		return wheel
	end

	return nil
end

local function get_rt_num(key)
	local tyre = get_rt_tyre()
	if not tyre then
		return nil
	end

	local n = tyre:FindFirstChild(key)
	if is_num_obj(n) then
		return n
	end

	return nil
end

local function get_wt_tyre(car_name, tyre_name)
	if not wt_root then
		return nil
	end

	local car = wt_root:FindFirstChild(car_name or wt_car_now)
	if not car or not car:IsA("Folder") then
		return nil
	end

	local tyre = car:FindFirstChild(tyre_name or wt_tyre_now)
	if tyre and tyre:IsA("Folder") then
		return tyre
	end

	return nil
end

local function get_wt_num(key, car_name, tyre_name)
	local tyre = get_wt_tyre(car_name, tyre_name)
	local n = tyre and tyre:FindFirstChild(key)
	if is_num_obj(n) then
		return n
	end
	return nil
end

local function get_rt_comp()
	local car = get_rt_car()
	if not car then
		return "---"
	end

	local info = car:FindFirstChild("Information")
	local tyre = info and info:FindFirstChild("Tyre")
	if tyre and tyre:IsA("StringValue") and tyre.Value ~= "" then
		return tyre.Value
	end

	return "---"
end

local function sync_wt_car_list()
	wt_car_vals = {}
	if wt_root then
		for _, x in ipairs(wt_root:GetChildren()) do
			if x:IsA("Model") then
				table.insert(wt_car_vals, x.Name)
			elseif x:IsA("Folder") then
				table.insert(wt_car_vals, x.Name)
			end
		end
	end

	table.sort(wt_car_vals)
	if #wt_car_vals == 0 then
		wt_car_vals = { "---" }
	end

	if not table.find(wt_car_vals, wt_car_now) then
		wt_car_now = wt_car_vals[1]
	end

	call_ctrl(wt_car, "SetValues", wt_car_vals)
	call_ctrl(wt_car, "SetValue", wt_car_now)
end

local function sync_wt_tyre_list()
	local car = wt_root and wt_root:FindFirstChild(wt_car_now)
	wt_tyre_vals = {}
	if car and car:IsA("Folder") then
		for _, x in ipairs(car:GetChildren()) do
			if x:IsA("Folder") then
				table.insert(wt_tyre_vals, x.Name)
			end
		end
	end
	table.sort(wt_tyre_vals)
	if #wt_tyre_vals == 0 then
		wt_tyre_vals = { "---" }
	end

	if not table.find(wt_tyre_vals, wt_tyre_now) then
		wt_tyre_now = wt_tyre_vals[1]
	end

	call_ctrl(wt_tyre, "SetValues", wt_tyre_vals)
	call_ctrl(wt_tyre, "SetValue", wt_tyre_now)
end

local wt_mem = {}
local rt_last_era = nil
local rt_last_comp = nil

local function get_mem(car_name, tyre_name)
	wt_mem[car_name] = wt_mem[car_name] or {}
	wt_mem[car_name][tyre_name] = wt_mem[car_name][tyre_name] or {}
	return wt_mem[car_name][tyre_name]
end

local function same_rt_sel()
	local era = get_rt_era()
	local comp = get_rt_comp()
	return era == wt_car_now and comp == wt_tyre_now
end

local function apply_mem_rt()
	local era = get_rt_era()
	local comp = get_rt_comp()
	if not era or not comp or comp == "---" then
		rt_last_era = nil
		rt_last_comp = nil
		return
	end

	if rt_last_era == era and rt_last_comp == comp then
		return
	end
	rt_last_era = era
	rt_last_comp = comp

	local mem = wt_mem[era] and wt_mem[era][comp]
	if not mem then
		return
	end

	for _, def in ipairs(wt_defs) do
		local v = mem[def.key]
		local rt_num = get_rt_num(def.key)
		if type(v) == "number" and rt_num then
			rt_num.Value = math.clamp(v, def.min, def.max)
		end
	end
end

local function sync_wt_slider()
	local def = wt_by_name[wt_val_now]
	if not def then
		return
	end

	local v = def.min
	local mem = wt_mem[wt_car_now] and wt_mem[wt_car_now][wt_tyre_now]
	local rt_num = get_rt_num(def.key)
	local wt_num = get_wt_num(def.key, wt_car_now, wt_tyre_now)
	local num = same_rt_sel() and (rt_num or wt_num) or wt_num

	if mem and type(mem[def.key]) == "number" then
		v = math.clamp(mem[def.key], def.min, def.max)
	elseif num then
		v = math.clamp(num.Value, def.min, def.max)
	end

	call_ctrl(wt_slider, "SetMin", def.min)
	call_ctrl(wt_slider, "SetMax", def.max)
	call_ctrl(wt_slider, "SetRounding", def.round)
	call_ctrl(wt_slider, "SetValue", v)
end

bind_changed(wt_car, function(v)
	wt_car_now = v
	sync_wt_tyre_list()
	sync_wt_slider()
end)

bind_changed(wt_tyre, function(v)
	wt_tyre_now = v
	sync_wt_slider()
end)

bind_changed(wt_val, function(v)
	wt_val_now = v
	sync_wt_slider()
end)

bind_changed(wt_slider, function(v)
	local def = wt_by_name[wt_val_now]
	if not def then
		return
	end

	local next_v = math.clamp(v, def.min, def.max)
	get_mem(wt_car_now, wt_tyre_now)[def.key] = next_v
	local rt_num = get_rt_num(def.key)

	if same_rt_sel() and rt_num then
		rt_num.Value = next_v
	end
end)

bind_changed(wt_no_deg, function(v)
	a_state.no_deg = v
end)

bind_changed(wt_delay, function(v)
	a_state.deg_delay = v
end)

local a_tcs = a_box.main:AddToggle("ach_tcs_enabled", {
	Text = "TCS Enabled",
	Default = a_tune.TCSEnabled,
})

bind_changed(a_tcs, function(v)
	a_tune.TCSEnabled = v
	if a_prof_key then
		save_prof(a_prof_key)
	end
end)

bind_changed(a_enabled, function(v)
	a_state.enabled = v
end)

bind_changed(a_nd_fx, function(v)
	a_state.nd_fx = v
	if v then
		nd_tick()
	end
end)

bind_changed(a_nd_vis, function(v)
	a_state.nd_vis = v
	if v then
		nd_tick()
	end
end)

sync_slider()
sync_wt_car_list()
sync_wt_tyre_list()
sync_wt_slider()
cap_rt()
do
	local gdrs = get_global_drs_value()
	if gdrs then
		a_state.global_drs = gdrs.Value
		call_ctrl(a_global_drs, "SetValue", a_state.global_drs)
	end
end

task.spawn(function()
	local vehicles = ws:WaitForChild("Vehicles")
	vehicles.ChildAdded:Connect(function(x)
		apply_tune(x)
	end)

	for _, car in ipairs(vehicles:GetChildren()) do
		apply_tune(car)
	end
end)

--// =========================
--// Corner Cuts
--// =========================
local c_box = {
	main = c_tab:AddLeftGroupbox("Main"),
	tune = c_tab:AddRightGroupbox("Tuning"),
}

local c_state = {
	enabled = true,
	visible = false,
	transparency = 0.4,
	shrink_x = 0,
	shrink_y = 0,
	shrink_z = 0,
	wall_collidable = true,
	dirty = true,
}

local c_orig = {}

local function get_corner_cuts_root()
	local timing = ws:FindFirstChild("Timing_System")
	if not timing then
		return nil
	end
	return timing:FindFirstChild("CornerCuts")
end

local function capture_cc_original(part)
	if c_orig[part] then
		return
	end
	-- Snapshot once so toggling/retuning always restores exact original state.
	c_orig[part] = {
		size = part.Size,
		can_touch = part.CanTouch,
		can_query = part.CanQuery,
		can_collide = part.CanCollide,
		transparency = part.Transparency,
		material = part.Material,
		color = part.Color,
	}
end

local function restore_cc_original(part)
	local orig = c_orig[part]
	if not orig then
		return
	end
	part.Size = orig.size
	part.CanTouch = orig.can_touch
	part.CanQuery = orig.can_query
	part.CanCollide = orig.can_collide
	part.Transparency = orig.transparency
	part.Material = orig.material
	part.Color = orig.color
end

local function parse_cc_kind(raw)
	if type(raw) ~= "string" then
		return nil
	end

	local upper = string.upper(raw)
	if string.find(upper, "WALL", 1, true) then
		return "WALL"
	end
	if string.find(upper, "CC", 1, true) or string.find(upper, "CUT", 1, true) then
		return "CC"
	end

	return nil
end

local function get_cc_kind(part, orig)
	local attr_kind = parse_cc_kind(part:GetAttribute("CornerCutType"))
		or parse_cc_kind(part:GetAttribute("CCType"))
		or parse_cc_kind(part:GetAttribute("Type"))
	if attr_kind then
		return attr_kind
	end

	local name_kind = parse_cc_kind(part.Name)
	if name_kind then
		return name_kind
	end

	local parent = part.Parent
	if parent then
		local parent_kind = parse_cc_kind(parent.Name)
		if parent_kind then
			return parent_kind
		end
	end

	if orig and orig.can_collide then
		return "WALL"
	end

	return "CC"
end

local function apply_corner_cut_part(part)
	capture_cc_original(part)
	local orig = c_orig[part]
	if not orig then
		return
	end

	if c_state.enabled then
		restore_cc_original(part)
		return
	end

	part.CanTouch = false
	part.CanQuery = false
	part.CanCollide = get_cc_kind(part, orig) == "WALL" and c_state.wall_collidable or false

	local sub = Vector3.new(c_state.shrink_x * 2, c_state.shrink_y * 2, c_state.shrink_z * 2)
	part.Size = Vector3.new(
		math.max(0.2, orig.size.X - sub.X),
		math.max(0.2, orig.size.Y - sub.Y),
		math.max(0.2, orig.size.Z - sub.Z)
	)

	part.Transparency = c_state.visible and c_state.transparency or 1
	part.Material = orig.material
	part.Color = orig.color
end

local function apply_corner_cuts()
	local root = get_corner_cuts_root()
	if not root then
		return
	end

	local seen = {}
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			seen[inst] = true
			apply_corner_cut_part(inst)
		end
	end

	for part in pairs(c_orig) do
		if not seen[part] or not part.Parent then
			c_orig[part] = nil
		end
	end
end

local c_enabled = c_box.main:AddToggle("cc_enabled", {
	Text = "Corner Cuts Enabled",
	Default = c_state.enabled,
})

local c_visible = c_box.main:AddToggle("cc_visible", {
	Text = "Visible",
	Default = c_state.visible,
})

local c_transparency = c_box.main:AddSlider("cc_transparency", {
	Text = "Transparency",
	Default = c_state.transparency,
	Min = 0,
	Max = 1,
	Rounding = 2,
})

local c_shrink_x = c_box.tune:AddSlider("cc_shrink_x", {
	Text = "Shrink X (studs)",
	Default = c_state.shrink_x,
	Min = 0,
	Max = 8,
	Rounding = 2,
})

local c_shrink_y = c_box.tune:AddSlider("cc_shrink_y", {
	Text = "Shrink Y (studs)",
	Default = c_state.shrink_y,
	Min = 0,
	Max = 4,
	Rounding = 2,
})

local c_shrink_z = c_box.tune:AddSlider("cc_shrink_z", {
	Text = "Shrink Z (studs)",
	Default = c_state.shrink_z,
	Min = 0,
	Max = 4,
	Rounding = 2,
})

local c_wall_collidable = c_box.tune:AddToggle("cc_wall_collidable", {
	Text = "Wall Collidable",
	Default = c_state.wall_collidable,
})

bind_many({
	{
		ctrl = c_enabled,
		set = function(v)
			c_state.enabled = v
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_visible,
		set = function(v)
			c_state.visible = v
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_transparency,
		set = function(v)
			c_state.transparency = math.clamp(v, 0, 1)
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_shrink_x,
		set = function(v)
			c_state.shrink_x = math.max(0, v)
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_shrink_y,
		set = function(v)
			c_state.shrink_y = math.max(0, v)
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_shrink_z,
		set = function(v)
			c_state.shrink_z = math.max(0, v)
			c_state.dirty = true
		end,
	},
	{
		ctrl = c_wall_collidable,
		set = function(v)
			c_state.wall_collidable = v
			c_state.dirty = true
		end,
	},
})

--// =========================
--// Pit System
--// =========================
local p_box = {
	main = p_tab:AddLeftGroupbox("Pit"),
	hold = p_tab:AddRightGroupbox("Hold"),
}

local p_state = {
	pit_limiter = false,
	speed_limiter = 80,
	pit_deployed = false,
	wheel_regen = 0,
	pit_time = 2.5,
	hold_limiter = false,
	hold_speed = false,
	hold_deployed = false,
	hold_regen = false,
	hold_time = false,
}

local function get_pit_info()
	local car = get_ui_car()
	local info = car and car:FindFirstChild("Information")
	return info and info:FindFirstChild("PitInfo") or nil
end

local function cap_pit()
	local pit = get_pit_info()
	if pit then
		local limiter = pit:FindFirstChild("PitLimiter")
		local speed = pit:FindFirstChild("SpeedLimiter")
		local deployed = pit:FindFirstChild("PitDeployed")
		local regen = pit:FindFirstChild("WheelRegen")
		local ptime = pit:FindFirstChild("PitTime")

		if limiter and limiter:IsA("BoolValue") then
			p_state.pit_limiter = limiter.Value
		end
		if speed and speed:IsA("NumberValue") then
			p_state.speed_limiter = speed.Value
		end
		if deployed and deployed:IsA("BoolValue") then
			p_state.pit_deployed = deployed.Value
		end
		if regen and regen:IsA("NumberValue") then
			p_state.wheel_regen = regen.Value
		end
		if ptime and ptime:IsA("NumberValue") then
			p_state.pit_time = ptime.Value
		end
	end
end

local function apply_pit_values(force)
	local pit = get_pit_info()
	if not pit then
		return
	end

	local limiter = pit:FindFirstChild("PitLimiter")
	local speed = pit:FindFirstChild("SpeedLimiter")
	local deployed = pit:FindFirstChild("PitDeployed")
	local regen = pit:FindFirstChild("WheelRegen")
	local ptime = pit:FindFirstChild("PitTime")

	if limiter and limiter:IsA("BoolValue") and (force or p_state.hold_limiter) then
		limiter.Value = p_state.pit_limiter
	end
	if speed and speed:IsA("NumberValue") and (force or p_state.hold_speed) then
		speed.Value = math.clamp(p_state.speed_limiter, 40, 300)
	end
	if deployed and deployed:IsA("BoolValue") and (force or p_state.hold_deployed) then
		deployed.Value = p_state.pit_deployed
	end
	if regen and regen:IsA("NumberValue") and (force or p_state.hold_regen) then
		regen.Value = math.clamp(p_state.wheel_regen, 0, 100)
	end
	if ptime and ptime:IsA("NumberValue") and (force or p_state.hold_time) then
		ptime.Value = math.clamp(p_state.pit_time, 0, 15)
	end
end

local function pit_tick()
	apply_pit_values(false)
end

local p_limiter = p_box.main:AddToggle("pit_limiter", {
	Text = "Pit Limiter",
	Default = p_state.pit_limiter,
})

local p_speed = p_box.main:AddSlider("pit_speed", {
	Text = "Speed Limiter",
	Default = p_state.speed_limiter,
	Min = 40,
	Max = 300,
	Rounding = 0,
})

local p_deployed = p_box.main:AddToggle("pit_deployed", {
	Text = "Pit Deployed",
	Default = p_state.pit_deployed,
})

local p_regen = p_box.main:AddSlider("pit_regen", {
	Text = "Wheel Regen",
	Default = p_state.wheel_regen,
	Min = 0,
	Max = 100,
	Rounding = 0,
})

local p_time = p_box.main:AddSlider("pit_time", {
	Text = "Pit Time (s)",
	Default = p_state.pit_time,
	Min = 0,
	Max = 15,
	Rounding = 1,
})

local p_hold_limiter = p_box.hold:AddToggle("pit_hold_limiter", {
	Text = "Hold Pit Limiter",
	Default = p_state.hold_limiter,
})

local p_hold_speed = p_box.hold:AddToggle("pit_hold_speed", {
	Text = "Hold Speed",
	Default = p_state.hold_speed,
})

local p_hold_deployed = p_box.hold:AddToggle("pit_hold_deployed", {
	Text = "Hold Pit Deployed",
	Default = p_state.hold_deployed,
})

local p_hold_regen = p_box.hold:AddToggle("pit_hold_regen", {
	Text = "Hold Wheel Regen",
	Default = p_state.hold_regen,
})

local p_hold_time = p_box.hold:AddToggle("pit_hold_time", {
	Text = "Hold Pit Time",
	Default = p_state.hold_time,
})

p_box.main:AddButton({
	Text = "Apply Once",
	Func = function()
		apply_pit_values(true)
	end,
})

p_box.main:AddButton({
	Text = "Read Current Pit",
	Func = function()
		cap_pit()
		call_ctrl(p_limiter, "SetValue", p_state.pit_limiter)
		call_ctrl(p_speed, "SetValue", p_state.speed_limiter)
		call_ctrl(p_deployed, "SetValue", p_state.pit_deployed)
		call_ctrl(p_regen, "SetValue", p_state.wheel_regen)
		call_ctrl(p_time, "SetValue", p_state.pit_time)
	end,
})

local p_init_sync = false
bind_many({
	{
		ctrl = p_limiter,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.pit_limiter = v
			apply_pit_values(true)
		end,
	},
	{
		ctrl = p_speed,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.speed_limiter = v
			apply_pit_values(true)
		end,
	},
	{
		ctrl = p_deployed,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.pit_deployed = v
			apply_pit_values(true)
		end,
	},
	{
		ctrl = p_regen,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.wheel_regen = v
			apply_pit_values(true)
		end,
	},
	{
		ctrl = p_time,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.pit_time = v
			apply_pit_values(true)
		end,
	},
	{
		ctrl = p_hold_limiter,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.hold_limiter = v
			pit_tick()
		end,
	},
	{
		ctrl = p_hold_speed,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.hold_speed = v
			pit_tick()
		end,
	},
	{
		ctrl = p_hold_deployed,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.hold_deployed = v
			pit_tick()
		end,
	},
	{
		ctrl = p_hold_regen,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.hold_regen = v
			pit_tick()
		end,
	},
	{
		ctrl = p_hold_time,
		set = function(v)
			if p_init_sync then
				return
			end
			p_state.hold_time = v
			pit_tick()
		end,
	},
})

p_init_sync = true
cap_pit()
call_ctrl(p_limiter, "SetValue", p_state.pit_limiter)
call_ctrl(p_speed, "SetValue", p_state.speed_limiter)
call_ctrl(p_deployed, "SetValue", p_state.pit_deployed)
call_ctrl(p_regen, "SetValue", p_state.wheel_regen)
call_ctrl(p_time, "SetValue", p_state.pit_time)
call_ctrl(p_hold_limiter, "SetValue", p_state.hold_limiter)
call_ctrl(p_hold_speed, "SetValue", p_state.hold_speed)
call_ctrl(p_hold_deployed, "SetValue", p_state.hold_deployed)
call_ctrl(p_hold_regen, "SetValue", p_state.hold_regen)
call_ctrl(p_hold_time, "SetValue", p_state.hold_time)
p_init_sync = false

--// =========================
--// Lap System
--// =========================
local reps_events = reps:FindFirstChild("Events")
local reps_values = reps:FindFirstChild("Values")
local timer_event = reps_events and reps_events:FindFirstChild("Timer")
local timer_info = reps_values and reps_values:FindFirstChild("TimerInfo")
local timer_info_value = timer_info and timer_info:FindFirstChild("Value")
local upgrade_event = reps_events and reps_events:FindFirstChild("UpgradeCar")

local has_timer_event = timer_event and timer_event:IsA("RemoteEvent")
local has_timer_info = timer_info_value and timer_info_value:IsA("StringValue")
local has_upgrade_event = upgrade_event and upgrade_event:IsA("RemoteFunction")

local ls_box = {
	lap_import = l_tab:AddLeftGroupbox("Lap Import"),
}

if not has_timer_event then
	ls_box.lap_import:AddLabel("Lap import is unavailable.")
else
	local ls_state = {
		s1 = nil,
		s2 = nil,
		s3 = nil,
	}

	local function has_lap_inputs()
		return type(ls_state.s1) == "number" and type(ls_state.s2) == "number" and type(ls_state.s3) == "number"
	end

	local function lap_sum()
		return ls_state.s1 + ls_state.s2 + ls_state.s3
	end

	ls_box.lap_import:AddInput("lap_import_s1", {
		Text = "S1 time",
		Default = "",
		Placeholder = "Input here",
		Callback = function(value)
			ls_state.s1 = to_nonneg_number(value)
		end,
	})

	ls_box.lap_import:AddInput("lap_import_s2", {
		Text = "S2 time",
		Default = "",
		Placeholder = "Input here",
		Callback = function(value)
			ls_state.s2 = to_nonneg_number(value)
		end,
	})

	ls_box.lap_import:AddInput("lap_import_s3", {
		Text = "S3 time",
		Default = "",
		Placeholder = "Input here",
		Callback = function(value)
			ls_state.s3 = to_nonneg_number(value)
		end,
	})

	ls_box.lap_import
		:AddButton({
			Text = "Instant",
			Func = function()
				if not has_lap_inputs() then
					return
				end
				timer_event:FireServer(1, ls_state.s1)
				timer_event:FireServer(2, ls_state.s2)
				timer_event:FireServer(3, ls_state.s3)
				timer_event:FireServer(4, lap_sum())
			end,
		})
		:AddButton({
			Text = "Accurate",
			Func = function()
				if not has_lap_inputs() then
					return
				end
				task.wait(ls_state.s1)
				timer_event:FireServer(1, ls_state.s1)
				task.wait(ls_state.s2)
				timer_event:FireServer(2, ls_state.s2)
				task.wait(ls_state.s3)
				timer_event:FireServer(3, ls_state.s3)
				timer_event:FireServer(4, lap_sum())
			end,
		})
end

--// =========================
--// Economy
--// =========================

local warning_text =
	"The autofarm is preset for BAKU with a 1989-1994 era car. Please adjust properly to ensure good results."

e_tab:UpdateWarningBox({
	Title = "Warning",
	Text = warning_text,
	IsNormal = false,
	Visible = true,
	LockSize = true,
})

local e_box = {
	af = e_tab:AddLeftGroupbox("Auto farm"),
	upgrades = e_tab:AddRightGroupbox("Upgrades"),
}
local e_state = {
	autofarm = {
		enabled = false,
		blatant = false,
		loop_delay = 5,
		sector_times = {
			[1] = 26,
			[2] = 32,
			[3] = 22,
		},
		sector_range = 1000,
	},
}

local function submit_lap(s1, s2, s3)
	if not has_timer_event then
		return
	end
	local tt = s1 + s2 + s3
	timer_event:FireServer(1, s1)
	timer_event:FireServer(2, s2)
	timer_event:FireServer(3, s3)
	timer_event:FireServer(4, tt)
end

local function parse_timer_seconds(val)
	if type(val) ~= "string" then
		return 0
	end
	local min, sec = string.match(val, "(%d+):(%d+)")
	min = tonumber(min) or 0
	sec = tonumber(sec) or 0
	return (min * 60) + sec
end

if not (has_timer_event and has_timer_info) then
	e_box.af:AddLabel("Auto farm is unavailable.")
else
	local af_enabled = e_box.af:AddToggle("autofarm_enabled", {
		Text = "Enable autofarm",
		Default = false,
	})

	local af_blatant = e_box.af:AddToggle("autofarm_blatant", {
		Text = "Enable blatant",
		Default = false,
	})
	af_blatant:OnChanged(function(state)
		e_state.autofarm.blatant = state
	end)

	local timer_value = timer_info_value

	af_enabled:OnChanged(function(state)
		e_state.autofarm.enabled = state

		if e_state.autofarm.enabled then
			task.spawn(function()
				while task.wait(e_state.autofarm.loop_delay) do
					if not e_state.autofarm.enabled then
						break
					end

					local s1_base = e_state.autofarm.sector_times[1] or 26
					local s2_base = e_state.autofarm.sector_times[2] or 32
					local s3_base = e_state.autofarm.sector_times[3] or 22
					local s_total = s1_base + s2_base + s3_base

					local should_submit = true
					if not e_state.autofarm.blatant and parse_timer_seconds(timer_value.Value) >= (780 - s_total) then
						should_submit = false
					end

					if should_submit then
						local s1 = s1_base + (math.random(1, e_state.autofarm.sector_range) / 1000)
						local s2 = s2_base + (math.random(1, e_state.autofarm.sector_range) / 1000)
						local s3 = s3_base + (math.random(1, e_state.autofarm.sector_range) / 1000)
						submit_lap(s1, s2, s3)
					end
				end
			end)
		end
	end)

	e_box.af:AddInput("autofarm_s1", {
		Text = "S1 time",
		Default = "26",
		Placeholder = "Input here",
		Callback = function(value)
			e_state.autofarm.sector_times[1] = to_nonneg_number(value)
		end,
	})

	e_box.af:AddInput("autofarm_s2", {
		Text = "S2 time",
		Default = "32",
		Placeholder = "Input here",
		Callback = function(value)
			e_state.autofarm.sector_times[2] = to_nonneg_number(value)
		end,
	})

	e_box.af:AddInput("autofarm_s3", {
		Text = "S3 time",
		Default = "22",
		Placeholder = "Input here",
		Callback = function(value)
			e_state.autofarm.sector_times[3] = to_nonneg_number(value)
		end,
	})

	e_box.af:AddSlider("autofarm_range_ms", {
		Text = "Range",
		Default = 1000,
		Min = 0,
		Max = 1000,
		Rounding = 0,
		Suffix = "ms",
		Callback = function(value)
			e_state.autofarm.sector_range = value
		end,
	})
end

local aero = {
	"Body Strakes",
	"Mirrors",
	"Floor",
	"Front Wing",
	"Rear Wing",
}
local chassis = {
	"Weight reduction",
	"Weight reduction2",
	"Thin nose",
	"Packaging",
}
local engine = {
	"Fuel",
	"ICE",
	"MGU-K",
	"Weight",
	"Turbo",
}

local upgrade_types = {
	"Aero",
	"Chassis",
	"Engine",
}

local era_cars = {
	["2025"] = {
		"BmRacing",
		"Karl-Ringer",
		"Werner",
		"DMB",
		"Bison GP",
		"Ferrucha",
		"Ascolt",
		"Hans",
		"Evans Racing",
		"Pelissier",
		"Montane",
		"Bolting Bisons",
		"Theron Doorn",
		"Schmutzig",
		"EX",
		"Santen",
		"Alten",
		"Saetta GP",
		"Mercury",
	},
}
local upgrade_era = "2025"

local upgrades_state = {
	manufacturers = {},
	types = {},
}

local function normalize_multi_values(values)
	local out = {}
	if type(values) ~= "table" then
		return out
	end

	for k, v in pairs(values) do
		if type(k) == "number" and type(v) == "string" then
			table.insert(out, v)
		elseif v == true and type(k) == "string" then
			table.insert(out, k)
		end
	end
	return out
end

if not has_upgrade_event then
	e_box.upgrades:AddLabel("Upgrades are unavailable.")
else
	local manufacturer_dropdown = e_box.upgrades:AddDropdown("upgrade_manufacturers", {
		Values = era_cars[upgrade_era],
		Default = nil,
		Multi = true,
		Text = "Manufacturers",
		Searchable = true,
	})

	manufacturer_dropdown:OnChanged(function(vals)
		upgrades_state.manufacturers = vals
	end)

	local types_dropdown = e_box.upgrades:AddDropdown("upgrade_types", {
		Values = upgrade_types,
		Default = nil,
		Multi = true,
		Text = "Types",
		Searchable = true,
	})

	types_dropdown:OnChanged(function(vals)
		upgrades_state.types = vals
	end)

	local function upgrade(era, kind, manufacturer, part)
		upgrade_event:InvokeServer(era, kind, manufacturer, part)
	end

	e_box.upgrades:AddButton({
		Text = "Upgrade",
		Func = function()
			local manufacturers = normalize_multi_values(upgrades_state.manufacturers)
			local selected_types = normalize_multi_values(upgrades_state.types)
			local do_aero = table.find(selected_types, "Aero") ~= nil
			local do_chassis = table.find(selected_types, "Chassis") ~= nil
			local do_engine = table.find(selected_types, "Engine") ~= nil

			for _, manufacturer in ipairs(manufacturers) do
				if do_aero then
					for _, part in ipairs(aero) do
						upgrade(upgrade_era, "Aero", manufacturer, part)
					end
				end
				if do_chassis then
					for _, part in ipairs(chassis) do
						upgrade(upgrade_era, "Chassis", manufacturer, part)
					end
				end
				if do_engine then
					for _, part in ipairs(engine) do
						upgrade(upgrade_era, "Engine", manufacturer, part)
					end
				end
			end
		end,
	})
end

--// =========================
--// Gravity
--// =========================
local og_grav = math.floor(ws.Gravity * 10) / 10
local og_grav_real = ws.Gravity

local g_box = {
	main = grav:AddLeftGroupbox("Main"),
	conds = grav:AddLeftGroupbox("Conditions"),
	hook = grav:AddRightGroupbox("Hook"),
	status = grav:AddRightGroupbox("Status"),
}

local g_state = {
	base_grav = og_grav,
	smooth_grav = og_grav,
	target_grav = og_grav,
	applied_grav = ws.Gravity,

	speed = 0,
	speed_delta = 0,
	cutoff_speed = 200,

	up_mult = 1.25,
	down_mult = 0.75,
	up_enabled = true,
	down_enabled = true,

	mode = "Off",

	hook_enabled = false,
	hook_target = "Actual Original",
	hook_custom = og_grav,

	status_dt = 0,
}

local g_cond = {
	accel = "Accelerating",
	brake = "Braking",
	over = "Speed Above Cutoff",
	under = "Speed Below Cutoff",
}

local g_cond_values = { g_cond.accel, g_cond.brake, g_cond.over, g_cond.under }
local g_up_modes = {}
local g_down_modes = {}

local g_main_enabled = g_box.main:AddToggle("grav_main_enabled", {
	Text = "Enabled",
	Default = false,
})

local g_main_gravity = g_box.main:AddSlider("grav_main_base", {
	Text = "Base Gravity",
	Default = g_state.base_grav,
	Min = 1,
	Max = 1000,
	Rounding = 1,
})

g_box.main:AddInput("grav_main_input", {
	Text = "Set Gravity",
	Default = "",
	Placeholder = "1 - 1000",
	Callback = function(value)
		local n = tonumber(value)
		if not n then
			return
		end

		n = math.clamp(n, 1, 1000)
		g_state.base_grav = n
		call_ctrl(g_main_gravity, "SetValue", n)
	end,
})

bind_changed(g_main_gravity, function(v)
	g_state.base_grav = v
end)

bind_changed(g_main_enabled, function(v)
	if not v then
		ws.Gravity = og_grav_real
		g_state.smooth_grav = og_grav_real
		g_state.mode = "Off"
		return
	end

	g_state.smooth_grav = ws.Gravity
end)

local g_cond_up = g_box.conds:AddDropdown("grav_cond_up", {
	Text = "Higher Gravity",
	Values = g_cond_values,
	Multi = true,
	Default = {},
})

local g_cond_down = g_box.conds:AddDropdown("grav_cond_down", {
	Text = "Lower Gravity",
	Values = g_cond_values,
	Multi = true,
	Default = {},
})

local g_cond_cutoff = g_box.conds:AddSlider("grav_cond_cutoff", {
	Text = "Cutoff Speed (studs/s)",
	Default = g_state.cutoff_speed,
	Min = 50,
	Max = 400,
	Rounding = 1,
})

local g_cond_up_mult = g_box.conds:AddSlider("grav_cond_up_mult", {
	Text = "Higher Multiplier",
	Default = g_state.up_mult,
	Min = 1,
	Max = 3,
	Rounding = 2,
})

local g_cond_down_mult = g_box.conds:AddSlider("grav_cond_down_mult", {
	Text = "Lower Multiplier",
	Default = g_state.down_mult,
	Min = 0.1,
	Max = 1,
	Rounding = 2,
})

local g_cond_up_on = g_box.conds:AddToggle("grav_cond_up_on", {
	Text = "Higher Enabled",
	Default = true,
})

local g_cond_down_on = g_box.conds:AddToggle("grav_cond_down_on", {
	Text = "Lower Enabled",
	Default = true,
})

bind_many({
	{
		ctrl = g_cond_up,
		set = function(v)
			g_up_modes = v
		end,
	},
	{
		ctrl = g_cond_down,
		set = function(v)
			g_down_modes = v
		end,
	},
	{
		ctrl = g_cond_cutoff,
		set = function(v)
			g_state.cutoff_speed = v
		end,
	},
	{
		ctrl = g_cond_up_mult,
		set = function(v)
			g_state.up_mult = v
		end,
	},
	{
		ctrl = g_cond_down_mult,
		set = function(v)
			g_state.down_mult = v
		end,
	},
	{
		ctrl = g_cond_up_on,
		set = function(v)
			g_state.up_enabled = v
		end,
	},
	{
		ctrl = g_cond_down_on,
		set = function(v)
			g_state.down_enabled = v
		end,
	},
})

local g_hook_targets = {
	"Actual Original",
	"Rounded Original",
	"Base Gravity",
	"Target Gravity",
	"Applied Gravity",
	"Custom",
}

local g_hook_short = {
	["Actual Original"] = "Actual",
	["Rounded Original"] = "Rounded",
	["Base Gravity"] = "Base",
	["Target Gravity"] = "Target",
	["Applied Gravity"] = "Applied",
	["Custom"] = "Custom",
}

local g_hook_enabled = g_box.hook:AddToggle("grav_hook_enabled", {
	Text = "Enabled",
	Default = false,
})

local g_hook_target = g_box.hook:AddDropdown("grav_hook_target", {
	Text = "Target",
	Values = g_hook_targets,
	Default = g_state.hook_target,
})

local g_hook_custom = g_box.hook:AddSlider("grav_hook_custom", {
	Text = "Custom Gravity",
	Default = g_state.hook_custom,
	Min = 1,
	Max = 1000,
	Rounding = 1,
})

bind_many({
	{
		ctrl = g_hook_target,
		set = function(v)
			g_state.hook_target = v
		end,
	},
	{
		ctrl = g_hook_custom,
		set = function(v)
			g_state.hook_custom = v
		end,
	},
})

local g_status_rows = {
	mode = g_box.status:AddLabel("Mode: Off"),
	speed = g_box.status:AddLabel("Speed: 0.0"),
	delta = g_box.status:AddLabel("Speed Delta: 0.000"),
	target = g_box.status:AddLabel("Target Gravity: 0.00"),
	applied = g_box.status:AddLabel("Applied Gravity: 0.00"),
	hook = g_box.status:AddLabel("Hook: Off (Actual Original)"),
}

local function set_label(label, txt)
	if label and label.SetText then
		pcall(label.SetText, label, txt)
	end
end

local function has_mode(mode_set, mode_key)
	if type(mode_set) ~= "table" then
		return false
	end
	if type(mode_set[mode_key]) == "boolean" then
		return mode_set[mode_key]
	end

	for _, value in pairs(mode_set) do
		if value == mode_key then
			return true
		end
	end

	return false
end

local function read_speed()
	local character = lp.Character
	if not character then
		return 0
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	return root.AssemblyLinearVelocity.Magnitude
end

local g_cond_checks = {
	[g_cond.accel] = function()
		return g_state.speed_delta > 0.05
	end,
	[g_cond.brake] = function()
		return g_state.speed_delta < -0.05
	end,
	[g_cond.over] = function()
		return g_state.speed >= g_state.cutoff_speed
	end,
	[g_cond.under] = function()
		return g_state.speed < g_state.cutoff_speed
	end,
}

local function condition_hit(mode_key)
	local fn = g_cond_checks[mode_key]
	return fn and fn() or false
end

local function eval_set(mode_set)
	local has_accel = has_mode(mode_set, g_cond.accel)
	local has_brake = has_mode(mode_set, g_cond.brake)
	local has_over = has_mode(mode_set, g_cond.over)
	local has_under = has_mode(mode_set, g_cond.under)
	local has_drive = has_accel or has_brake
	local has_speed = has_over or has_under

	if has_drive then
		return (has_accel and condition_hit(g_cond.accel)) or (has_brake and condition_hit(g_cond.brake))
	end
	if has_speed then
		return (has_over and condition_hit(g_cond.over)) or (has_under and condition_hit(g_cond.under))
	end

	return false
end

local g_hook_getters = {
	["Actual Original"] = function()
		return og_grav_real
	end,
	["Rounded Original"] = function()
		return og_grav
	end,
	["Base Gravity"] = function()
		return g_state.base_grav
	end,
	["Target Gravity"] = function()
		return g_state.target_grav
	end,
	["Applied Gravity"] = function()
		return g_state.applied_grav
	end,
	["Custom"] = function()
		return g_state.hook_custom
	end,
}

local function hook_value()
	local fn = g_hook_getters[g_state.hook_target]
	return fn and fn() or og_grav_real
end

local hook_ready = false
local function init_hook()
	if hook_ready then
		return
	end

	local mt = getrawmetatable(game)
	local old_index = mt.__index

	setreadonly(mt, false)
	mt.__index = newcclosure(function(self, key)
		if self == ws and key == "Gravity" and g_state.hook_enabled then
			return hook_value()
		end

		if type(old_index) == "function" then
			return old_index(self, key)
		end

		return old_index[key]
	end)
	setreadonly(mt, true)
	hook_ready = true
end

bind_changed(g_hook_enabled, function(v)
	g_state.hook_enabled = v
	if v then
		init_hook()
	end
end)

-- Shared scheduler for non-gravity periodic tasks to reduce polling threads.
local sched = {
	act = 0,
	nd = 0,
	rt = 0,
	mem = 0,
	deg = 0,
	cc = 0,
	pit = 0,
}

local function run_periodic(dt)
	if a_state.enabled then
		sched.act += dt
		if sched.act >= 0.25 then
			sched.act = 0
			destroy_named(lp, "ACTune")
			destroy_named(reps:FindFirstChild("Events"), "ACTune")
		end
	else
		sched.act = 0
	end

	if a_state.nd_fx or a_state.nd_vis then
		sched.nd += dt
		if sched.nd >= 0.2 then
			sched.nd = 0
			nd_tick()
		end
	else
		sched.nd = 0
	end

	if a_state.force_drs or a_state.df_lock or a_state.global_drs_lock then
		sched.rt += dt
		if sched.rt >= 0.15 then
			sched.rt = 0
			rt_tick()
		end
	else
		sched.rt = 0
	end

	sched.mem += dt
	if sched.mem >= 0.3 then
		sched.mem = 0
		apply_mem_rt()
	end

	if a_state.no_deg then
		sched.deg += dt
		if sched.deg >= a_state.deg_delay then
			sched.deg = 0
			local car = get_ui_car()
			if car then
				refresh_tyres(car)
			end
		end
	else
		sched.deg = 0
	end

	if (not c_state.enabled) or c_state.dirty then
		sched.cc += dt
		if c_state.dirty or sched.cc >= 0.5 then
			sched.cc = 0
			apply_corner_cuts()
			c_state.dirty = false
		end
	else
		sched.cc = 0
	end

	sched.pit += dt
	if sched.pit >= 0.15 then
		sched.pit = 0
		pit_tick()
	end
end

run_service.Heartbeat:Connect(function(dt)
	local ok, err = xpcall(function()
		run_periodic(dt)

		local key = car_key(get_ui_car())
		if key ~= a_prof_key then
			if a_prof_key then
				save_prof(a_prof_key)
			end
			a_prof_key = key
			if key and not load_prof(key) then
				save_prof(key)
			end
			sync_slider()
		end

		local speed = read_speed()
		g_state.speed_delta = speed - g_state.speed
		g_state.speed = speed

		if g_main_enabled.Value then
			local up_hit = g_state.up_enabled and eval_set(g_up_modes)
			local down_hit = g_state.down_enabled and eval_set(g_down_modes)
			local base = g_state.base_grav
			local target = base

			if up_hit and not down_hit then
				target = math.clamp(base * g_state.up_mult, 1, 1000)
				g_state.mode = "Higher"
			elseif down_hit and not up_hit then
				target = math.clamp(base * g_state.down_mult, 1, 1000)
				g_state.mode = "Lower"
			else
				g_state.mode = "Base"
			end

			g_state.target_grav = target
			local alpha = 1 - math.exp(-10 * dt)
			g_state.smooth_grav = g_state.smooth_grav + (target - g_state.smooth_grav) * alpha

			if math.abs(ws.Gravity - g_state.smooth_grav) > 0.01 then
				ws.Gravity = g_state.smooth_grav
			end
		else
			g_state.mode = "Off"
			g_state.target_grav = og_grav
			g_state.smooth_grav = og_grav
		end

		g_state.applied_grav = ws.Gravity
		g_state.status_dt += dt
		if g_state.status_dt < 0.1 then
			return
		end

		g_state.status_dt = 0
		set_label(g_status_rows.mode, "Mode: " .. g_state.mode)
		set_label(g_status_rows.speed, string.format("Speed: %.1f", g_state.speed))
		set_label(g_status_rows.delta, string.format("Speed Delta: %.3f", g_state.speed_delta))
		set_label(g_status_rows.target, string.format("Target Gravity: %.2f", g_state.target_grav))
		set_label(g_status_rows.applied, string.format("Applied Gravity: %.2f", g_state.applied_grav))
		set_label(
			g_status_rows.hook,
			string.format("Hook: %s (%s)", g_state.hook_enabled and "On" or "Off", g_hook_short[g_state.hook_target])
		)
	end, debug.traceback)

	if not ok then
		warn("rre: Heartbeat error: " .. tostring(err))
	end
end)
