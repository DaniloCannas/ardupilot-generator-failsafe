# ArduPilot generator failsafe

Lua failsafe for an **ArduCopter** powered by a petrol generator and a buffer battery.

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
