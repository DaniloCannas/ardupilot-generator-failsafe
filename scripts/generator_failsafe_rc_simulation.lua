-- ArduCopter generator failsafe: RC simulation version
--
-- TEST SCRIPT ONLY. Do not install this together with generator_failsafe.lua.
--
-- RC7 high for five continuous seconds simulates generator RPM below 500 and
-- commands RTL. After that event, RC8 high simulates 3501 mAh consumed from
-- the buffer battery and commands LAND at the aircraft's current position.

-- Use two spare, unassigned RC channels. rc:get_pwm() is one-indexed.
local RC_RPM_FAIL_CHANNEL = 7
local RC_MAH_LAND_CHANNEL = 8
local RC_HIGH_PWM = 1800

local SIMULATED_RPM = 0
local RPM_MIN = 500
local RPM_TIME_MS = 5000
local MAH_TO_LAND = 3500
local SIMULATED_MAH_ON_SWITCH = 3501

-- ArduCopter mode numbers.
local MODE_RTL = 6
local MODE_LAND = 9
local UPDATE_MS = 100

local low_rpm_since = nil
local generator_failed = false
local land_commanded = false

local function channel_is_high(channel)
    local pwm = rc:get_pwm(channel)
    return pwm ~= nil and pwm >= RC_HIGH_PWM
end

local function reset_state()
    low_rpm_since = nil
    generator_failed = false
    land_commanded = false
end

function update()
    -- The simulator is completely inactive on the ground, even when armed.
    local in_flight = arming:is_armed() and vehicle:get_likely_flying()
    if not in_flight then
        reset_state()
        return update, UPDATE_MS
    end

    if not generator_failed then
        -- RC7 high represents an RPM reading of zero, which is below RPM_MIN.
        local simulated_rpm = channel_is_high(RC_RPM_FAIL_CHANNEL) and SIMULATED_RPM or RPM_MIN

        if simulated_rpm < RPM_MIN then
            if low_rpm_since == nil then
                low_rpm_since = millis()
                gcs:send_text(5, "Generator SIM: low RPM timer started")
            elseif millis() - low_rpm_since >= RPM_TIME_MS then
                generator_failed = true
                gcs:send_text(2, "Generator SIM: 5s low RPM, RTL")

                -- RTL needs a valid position. LAND is the safe fallback.
                if not vehicle:set_mode(MODE_RTL) then
                    gcs:send_text(2, "Generator SIM: RTL rejected, LAND")
                    land_commanded = vehicle:set_mode(MODE_LAND)
                end
            end
        else
            if low_rpm_since ~= nil then
                gcs:send_text(6, "Generator SIM: low RPM timer cancelled")
            end
            low_rpm_since = nil
        end
    end

    -- RC8 works only after the simulated generator failure has been confirmed.
    if generator_failed and not land_commanded and channel_is_high(RC_MAH_LAND_CHANNEL) then
        local simulated_consumption_mah = SIMULATED_MAH_ON_SWITCH

        if simulated_consumption_mah > MAH_TO_LAND then
            if vehicle:set_mode(MODE_LAND) then
                land_commanded = true
                gcs:send_text(2, "Generator SIM: 3501mAh, LAND here")
            end
        end
    end

    return update, UPDATE_MS
end

return update, UPDATE_MS
