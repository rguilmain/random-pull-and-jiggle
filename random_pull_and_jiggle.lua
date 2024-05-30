--[[

    Random Pull and Jiggle
    by RichGuilmain
    
    Version 2.1
    + Only attaches bands to unlocked segments
    + Only uses maximum wiggle power if specified via new GUI checkbox
    + Updates default parameter settings
    
]]--


-- Setup
math.randomseed(os.time())
num_segments = structure.GetCount()
starting_wiggle_power = behavior.GetWigglePower()
starting_score = current.GetScore()

unlocked_segments = {}
for i=1, num_segments do
    if structure.IsLocked(i) == false then
        table.insert(unlocked_segments, i)
    end
end


-- Parameters
min_bands = 1
max_bands = 5
min_band_dist = 0.0
max_band_dist = 5.0
min_band_goal = 0.0
max_band_goal = 0.0
min_band_str = 1.0
max_band_str = 1.0
min_wiggles_out = 1
max_wiggles_out = 3
max_wiggles_in = 25
mutate_before = 0
shake_before = 0
mutate_after = 0
shake_after = 0
use_max_wiggle_power = false


function Round(n)
    return math.floor(n * 1000 + 0.5) / 1000
end


function RandFloat(min, max)
    return min + (max - min) * math.random()
end


function AddRandomBand()
    local origin = unlocked_segments[math.random(#unlocked_segments)]
    local x_axis = math.random(num_segments)
    local y_axis = math.random(num_segments)
    local rho =  RandFloat(min_band_dist, max_band_dist)
    local theta = math.rad(180 * math.random())
    local phi = math.rad(360 * math.random())
    if not pcall(band.Add, origin, x_axis, y_axis, rho, theta, phi) then
        origin = AddRandomBand()
    end
    return origin
end


function WiggleOut()
    -- Attach random bands to random segments
    for i=1, math.random(min_bands, max_bands) do
        selection.Select(AddRandomBand())
        band.SetStrength(i, RandFloat(min_band_str, max_band_str))
        band.SetGoalLength(i, RandFloat(min_band_goal, max_band_goal))
    end
    
    -- Wiggle out, and save any better solutions we find along the way
    local wiggle_out_improved_score = false
    for i=1, math.random(min_wiggles_out, max_wiggles_out) do
        structure.WiggleAll(1)
        if current.GetScore() > recentbest.GetScore() then
            recentbest.Save()
            wiggle_out_improved_score = true
        end
    end
    
    -- Use the best intermediary configuration if any scored better than the baseline
    if wiggle_out_improved_score then
        recentbest.Restore()
    end
    band.DeleteAll()
end


function WiggleBack()
    -- Returns true if wiggling back scores better than the recent best baseline
    local recent_best_score = recentbest.GetScore()
    local function_start_score = current.GetScore()
    
    for i=1, max_wiggles_in do
        -- Measure the improvement from one wiggle
        local loop_start_score = current.GetScore()
        structure.WiggleAll(1)
        local loop_end_score = current.GetScore()
        
        -- Break if we stop making progress
        if (loop_end_score - loop_start_score < 0.001) then
            break
        end
        
        -- Break if it looks like we won't make it back to our baseline score in time
        local remaining_gain = recent_best_score - loop_end_score
        local average_loop_gain = (loop_end_score - function_start_score) / i
        local remaining_wiggles = max_wiggles_in - i
        if (remaining_gain > average_loop_gain * remaining_wiggles) then
            break
        end
    end
    
    return current.GetScore() > recent_best_score
end


function Mutate(level)
    if level == 1 then
        structure.MutateSidechainsSelected(1)
    end
    if level == 2 then
        structure.MutateSidechainsAll(1)
    end
end


function Shake(level)
    if level == 1 then
        structure.ShakeSidechainsSelected(1)
    end
    if level == 2 then
        structure.ShakeSidechainsAll(1)
    end
end


function PullAndJiggle()
    WiggleOut()
    
    -- Mutate/shake before wiggling back together
    Mutate(mutate_before)
    Shake(shake_before)
    
    local wiggle_back_improved_score = WiggleBack()
    
    -- Mutate/shake after wiggling back together
    if wiggle_back_improved_score then
        Mutate(mutate_after)
        Shake(shake_after)
    end

    -- Clean up and save solution if we improved over the baseline
    selection.DeselectAll()
    if current.GetScore() > recentbest.GetScore() then
        recentbest.Save()
    end
end


function MonotonicPullAndJiggle()
    local starting_score = current.GetScore()
    PullAndJiggle()
    recentbest.Restore()
    local ending_score = current.GetScore()
    local score_delta = Round(ending_score - starting_score)
    if score_delta > 0.0 then
        print(os.date("%X"), "Increased score by", score_delta, "to", Round(ending_score))
    end
end


function MainDialog()
    local args = dialog.CreateDialog("Random Pull and Jiggle 2.1")
    args.doc1 = dialog.AddLabel("Randomly pulls the protein around and then wiggles")
    args.doc2 = dialog.AddLabel("it back together to escape local optima and find")
    args.doc3 = dialog.AddLabel("better neighboring configurations until canceled.")
    args.doc4 = dialog.AddLabel("Number of bands:")
    args.min_bands = dialog.AddSlider("min", min_bands, 1, 10, 0)
    args.max_bands = dialog.AddSlider("max", max_bands, 1, 10, 0)
    args.doc5 = dialog.AddLabel("Band lengths:")
    args.min_band_dist = dialog.AddSlider("min", min_band_dist, 0.0, 20.0, 1)
    args.max_band_dist = dialog.AddSlider("max", max_band_dist, 0.0, 20.0, 1)
    args.doc6 = dialog.AddLabel("Number of wiggles in:")
    args.max_wiggles_in = dialog.AddSlider("max", max_wiggles_in, 1, 100, 0)
    args.doc7 = dialog.AddLabel("Amount to mutate/shake before/after wiggling in:")
    args.doc8 = dialog.AddLabel("Amounts: 0 = none, 1 = selected, 2 = all (slower)")
    args.mutate_before = dialog.AddSlider("Mutate before", mutate_before, 0, 2, 0)
    args.shake_before = dialog.AddSlider("Shake before", shake_before, 0, 2, 0)
    args.doc9 = dialog.AddLabel("Only runs if wiggling back in improves baseline:")
    args.mutate_after = dialog.AddSlider("Mutate after", mutate_after, 0, 2, 0)
    args.shake_after = dialog.AddSlider("Shake after", shake_after, 0, 2, 0)
    args.use_max_wiggle_power = dialog.AddCheckbox("Use max wiggle power", use_max_wiggle_power)
    args.ok = dialog.AddButton("OK", 1)
    args.more = dialog.AddButton("More", 2)
    args.cancel = dialog.AddButton("Cancel", 0)
    return_code = dialog.Show(args)
    
    if return_code > 0 then
        min_bands = args.min_bands.value
        max_bands = args.max_bands.value
        min_band_dist = args.min_band_dist.value
        max_band_dist = args.max_band_dist.value
        max_wiggles_in = args.max_wiggles_in.value
        mutate_before = args.mutate_before.value
        shake_before = args.shake_before.value
        mutate_after = args.mutate_after.value
        shake_after = args.shake_after.value
        use_max_wiggle_power = args.use_max_wiggle_power.value
    end
    
    return return_code
end


function SecondaryDialog()
    local args = dialog.CreateDialog("Random Pull and Jiggle 2.1")
    args.doc1 = dialog.AddLabel("Band goal lengths:")
    args.min_band_goal = dialog.AddSlider("min", min_band_goal, 0.0, 20.0, 1)
    args.max_band_goal = dialog.AddSlider("max", max_band_goal, 0.0, 20.0, 1)
    args.doc2 = dialog.AddLabel("Band strengths:")
    args.min_band_str = dialog.AddSlider("min", min_band_str, 0.0, 20.0, 1)
    args.max_band_str = dialog.AddSlider("max", max_band_str, 0.0, 20.0, 1)
    args.doc3 = dialog.AddLabel("Number of wiggles out:")
    args.min_wiggles_out = dialog.AddSlider("min", min_wiggles_out, 1, 10, 0)
    args.max_wiggles_out = dialog.AddSlider("max", max_wiggles_out, 1, 10, 0)
    args.ok = dialog.AddButton("OK", 1)
    args.cancel = dialog.AddButton("Cancel", 0)
    return_code = dialog.Show(args)
    
    if return_code > 0 then
        min_band_goal = args.min_band_goal.value
        max_band_goal = args.max_band_goal.value
        min_band_str = args.min_band_str.value
        max_band_str = args.max_band_str.value
        min_wiggles_out = args.min_wiggles_out.value
        max_wiggles_out = args.max_wiggles_out.value
    end
    
    return return_code
end


function GetParams()
    repeat
        main_dialog_return_code = MainDialog()
        if main_dialog_return_code == 2 then
            SecondaryDialog()
        end
    until main_dialog_return_code < 2
    return main_dialog_return_code == 1
end


function ValidateParams()
    if min_bands > max_bands then
        print("Bad parameters. Min bands must be less than max bands.")
        return false
    end
    if min_band_dist > max_band_dist then
        print("Bad parameters. Min band length must be less than max band length.")
        return false
    end
    if min_band_goal > max_band_goal then
        print("Bad parameters. Min band goal length must be less than max band goal length.")
        return false
    end
    if min_band_str > max_band_str then
        print("Bad parameters. Min band strength out must be less than max band strength.")
        return false
    end
    if min_wiggles_out > max_wiggles_out then
        print("Bad parameters. Min wiggles out must be less than max wiggles out.")
        return false
    end
    return true
end


function LevelName(level)
    level_names = {"no", "selected", "all"}
    return level_names[level+1]
end


function SetWigglePower()
    if use_max_wiggle_power then
        if behavior.HighPowerAllowed() then
            behavior.SetWigglePower("h")
        else
            behavior.SetWigglePower("m")
        end
    end
end


function Main()
    -- Get parameters
    if not GetParams() or not ValidateParams() then
        return
    end
    
    -- Initialize
    SetWigglePower()
    band.DeleteAll()
    selection.DeselectAll()
    recentbest.Save()
    
    -- Log settings to the console
    print(os.date("%X"), "Random Pull and Jiggle 2.1")
    print(os.date("%X"), "########## SETTINGS ##########")
    print(os.date("%X"), "Num bands:", "min =", min_bands, "max =", max_bands)
    print(os.date("%X"), "Band lengths:", "min =", min_band_dist, "max =", max_band_dist)
    print(os.date("%X"), "Band goal lengths:", "min =", min_band_goal, "max =", max_band_goal)
    print(os.date("%X"), "Band strengths:", "min =", min_band_str, "max =", max_band_str)
    print(os.date("%X"), "Wiggles out:", "min =", min_wiggles_out, "max =", max_wiggles_out)
    print(os.date("%X"), "Wiggles in:", "min =", 1, "max =", max_wiggles_in)
    print(os.date("%X"), "Before:", "mutate =", LevelName(mutate_before), "shake =", LevelName(shake_before))
    print(os.date("%X"), "After:", "mutate =", LevelName(mutate_after), "shake =", LevelName(shake_after))
    print(os.date("%X"), "Wiggle power:", behavior.GetWigglePower())
    print(os.date("%X"), "##### PULLING AND JIGGLING... #####")
    print(os.date("%X"), "Starting with a score of", Round(starting_score)) 
    
    -- Run
    while true do
        MonotonicPullAndJiggle()
    end
end


function Cleanup()
    if current.GetScore() < recentbest.GetScore() then
        recentbest.Restore()
    end
    band.DeleteAll()
    selection.DeselectAll()
    behavior.SetWigglePower(starting_wiggle_power)
    local ending_score = current.GetScore()
    print(os.date("%X"), "Total score increase of", Round(ending_score - starting_score))
    print(os.date("%X"), "Finished with a score of", Round(ending_score))
end


xpcall(Main, Cleanup)