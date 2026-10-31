local ADDON, ns = ...
local L = ns.Locale:Base()

-- Test mode and probe (7.10). Check details and probe facts are raw API values for the developers
-- and stay untranslated; only these lines are.
L.TEST_HELP = "run the self-test against this client and take a screenshot"
L.TEST_HELP_PROBE = "record raw facts about this client for the developers"
L.TEST_NOT_IN_COMBAT = "The test does not run in combat. Try again once the fight is over."
L.TEST_SUMMARY = "Test finished: {passed} passed, {failed} failed, {skipped} skipped."
L.TEST_LINE = "{state} {id}: {detail}"
L.TEST_PASS = "pass"
L.TEST_FAIL = "FAIL"
L.TEST_SKIP = "skip"
L.TEST_OPEN_QUEST_DIALOG = "Talk to a quest giver first for the screenshot."
L.TEST_RELOAD = "Type /reload to save the results."
L.TEST_NOT_STORED = "The saved data comes from a newer Ashmark, so nothing is stored. The full report follows."
L.TEST_LATE = "Later result: {what}"
L.TEST_PROBE_DONE = "The probe recorded {count} facts."
L.TEST_PROBE_NEXT = "Accept a quest and start a fight this session: the probe records both."
