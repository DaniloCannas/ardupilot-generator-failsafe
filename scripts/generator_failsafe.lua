-- ArduCopter generator failsafe
--
-- If generator RPM stays below RPM_MIN for RPM_TIME_MS while flying:
--   1. command RTL;
--   2. measure mAh consumed by the buffer battery from that instant;
--   3. command LAND at the current position after MAH_TO_LAND mAh.

local RPM_INSTANCE = 0       -- RPM1 = 0, RPM2 = 1, ...
local BATT_INSTANCE = 0      -- BATT = 0, BATT2 = 1, ...

local RPM_MIN = 500
local RPM_TIME_MS = 4000
local MAH_TO_LAND = 3500

-- ArduCopter mode numbers.
local MODE_RTL = 6
local MODE_LAND = 9
local UPDATE_MS = 100

-- Treat loss of RPM telemetry while airborne as a generator failure.
-- Set to false only if a transient missing RPM value is expected in flight.
local NIL_RPM_IS_FAILURE = true

local low_rpm_since = nil
local generator_failed = false
local mah_at_failure = nil
local land_commanded = false
local rpm_missing_reported = false
local mah_missing_reported = false

local function reset_state()
    low_rpm_since = nil
    generator_failed = false
    mah_at_failure = nil
    land_commanded = false
    rpm_missing_reported = false
    mah_missing_reported = false
end

function update()
    -- Arming alone is not enough: the generator can be operated on the ground.
    -- This makes the whole state machine inactive and resets it after landing.
    local in_flight = arming:is_armed() and vehicle:get_likely_flying()
    if not in_flight then
        reset_state()
        return update, UPDATE_MS
    end

    local now = millis()
    local rpm = RPM:get_rpm(RPM_INSTANCE)

    if rpm == nil then
        if not rpm_missing_reported then
            gcs:send_text(2, "Generator FS: RPM unavailable")
            rpm_missing_reported = true
        end

        if NIL_RPM_IS_FAILURE then
            rpm = 0
        else
            return update, UPDATE_MS
        end
    else
        rpm_missing_reported = false
    end

    if not generator_failed then
        if rpm < RPM_MIN then
            if low_rpm_since == nil then
                low_rpm_since = now
            elseif now - low_rpm_since >= RPM_TIME_MS then
                generator_failed = true
                mah_at_failure = battery:consumed_mah(BATT_INSTANCE)

                gcs:send_text(2, "Generator FS: failure confirmed, RTL")

                -- If RTL is rejected (for example, no valid position), land now.
                if not vehicle:set_mode(MODE_RTL) then
                    gcs:send_text(2, "Generator FS: RTL rejected, LAND")
                    land_commanded = vehicle:set_mode(MODE_LAND)
                end

                if mah_at_failure == nil then
                    gcs:send_text(2, "Generator FS: battery mAh unavailable")
                    mah_missing_reported = true
                end
            end
        else
            -- RPM recovered before the four-second confirmation period.
            low_rpm_since = nil
        end
    end

    if generator_failed and not land_commanded and mah_at_failure ~= nil then
        local mah_now = battery:consumed_mah(BATT_INSTANCE)

        if mah_now == nil then
            if not mah_missing_reported then
                gcs:send_text(2, "Generator FS: battery mAh lost")
                mah_missing_reported = true
            end
        else
            local used_since_failure = math.max(0, mah_now - mah_at_failure)

            if used_since_failure >= MAH_TO_LAND then
                if vehicle:set_mode(MODE_LAND) then
                    land_commanded = true
                    gcs:send_text(2, "Generator FS: mAh limit, LAND here")
                end
            end
        end
    end

    return update, UPDATE_MS
end

return update, UPDATE_MS
