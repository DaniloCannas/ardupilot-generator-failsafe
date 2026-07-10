# ArduPilot generator failsafe

Lua failsafe for an **ArduCopter** powered by a petrol generator and a buffer battery. The production script is suitable for the intended 10-inch copter once its RPM and battery-monitor instances are configured and the complete setup has been validated.

While the copter is flying, a generator RPM below 500 for four uninterrupted seconds confirms a generator failure. The script commands RTL and takes a baseline of the buffer battery's consumed capacity. After a further 3500 mAh are consumed, it commands LAND at the current position.

The script is inactive on the ground, including when the vehicle is armed. It resets after landing, so ground tests or normal generator shut-down do not start an RTL or mAh counter.

## Requirements

- ArduCopter with Lua scripting and an SD card.
- A configured RPM sensor for the generator.
- A battery monitor with a valid current measurement for the buffer battery.
- Reliable GPS/position estimation for RTL and position-holding LAND.

The script uses `RPM1` and `BATT` by default. Change `RPM_INSTANCE` to `1` for `RPM2`, and `BATT_INSTANCE` to `1` for `BATT2`.

## Installation

1. Set `SCR_ENABLE = 1` and reboot the flight controller.
2. Copy [`scripts/generator_failsafe.lua`](scripts/generator_failsafe.lua) to `APM/scripts/` on the flight controller's SD card.
3. Check in the GCS that the script has loaded without errors.
4. Verify the RPM source and the battery current reading before any flight test.

## RC simulation script for a smaller test drone

[`scripts/generator_failsafe_rc_simulation.lua`](scripts/generator_failsafe_rc_simulation.lua) is a separate **test-only** script. It needs neither a real generator nor a battery-current measurement, and must never be installed at the same time as the production script.

The defaults use two spare receiver channels:

| Action | Default channel | Trigger |
| --- | --- | --- |
| Simulate generator RPM below 500 | RC7 | Hold high (>= 1800 PWM) for 5 continuous seconds; script commands RTL. |
| Simulate >3500 mAh after generator failure | RC8 | Raise after RTL has been commanded; script simulates 3501 mAh and commands LAND at the current position. |

Change `RC_RPM_FAIL_CHANNEL`, `RC_MAH_LAND_CHANNEL`, and `RC_HIGH_PWM` at the start of the simulation script if your radio uses other channels or switch positions. The channels must be spare: do not assign them to a flight mode or any other vehicle function (for example, leave `RC7_OPTION` and `RC8_OPTION` disabled when using the defaults).

### Test sequence

1. Remove or rename `generator_failsafe.lua` on the flight controller; install only `generator_failsafe_rc_simulation.lua`.
2. Confirm in the GCS that both selected RC channels are received and that the script reports no errors.
3. With the switches low, take off in a clear, low-risk area with a reliable GPS position.
4. Raise and hold the RC7 switch for five seconds. Confirm the `Generator SIM` message and RTL.
5. While still airborne, raise RC8. It simulates 3501 mAh after the failure and commands LAND at the current position.
6. After landing, return both switches low. The script resets itself only after it determines that the copter is no longer flying.

If normal RTL would reach home and land before step 5, test RC8 shortly after RTL starts, or set `RTL_ALT_FINAL_M` to a non-zero value for the test and review the energy budget. The simulation script uses the same in-flight guard as the production script, so operating the switches on the ground does nothing.

## Behaviour and safeguards

- The trigger requires four **continuous** seconds below 500 RPM. A recovery before four seconds cancels the timer.
- RPM telemetry missing in flight is treated as an RPM of zero by default. Set `NIL_RPM_IS_FAILURE` to `false` only when that is intentional.
- Once confirmed, generator failure is latched for the flight. Restarting the generator does not cancel RTL or the 3500 mAh reserve logic.
- If RTL is rejected, the script attempts LAND immediately.
- If the battery monitor cannot report consumed mAh, RTL is still commanded but the 3500 mAh LAND threshold cannot be evaluated; configure an independent native critical battery failsafe as a backup.

`LAND` is commanded wherever the aircraft is when the extra 3500 mAh is reached. To keep the aircraft from being repositioned by pilot stick input during LAND, set `LAND_REPOSITION = 0`.

By default, ArduCopter RTL may land automatically when it reaches home. If the 3500 mAh threshold must be the only condition that commands LAND after arrival, configure `RTL_ALT_FINAL_M` to a non-zero hover altitude and validate the energy budget.

## Safety checklist

- Keep ArduPilot's normal voltage/capacity failsafes enabled as an independent backup.
- Enable script checksum pre-arm checks (`SCR_LD_CHECKSUM` and `SCR_RUN_CHECKSUM`) after installation.
- Validate the complete logic in SITL, then with a restrained, low-risk flight test and onboard logging.
- Do not apply this script to ArduPlane or QuadPlane without changing the flight-mode values and reviewing the landing behaviour.

## References

- [ArduPilot Lua scripting](https://ardupilot.org/dev/docs/common-lua-scripts.html)
- [ArduCopter RTL mode](https://ardupilot.org/copter/docs/rtl-mode.html)
- [ArduCopter LAND mode](https://ardupilot.org/copter/docs/land-mode.html)
- [ArduCopter battery failsafe](https://ardupilot.org/copter/docs/failsafe-battery.html)

## License

MIT. See [LICENSE](LICENSE).
