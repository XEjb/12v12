local PRINT_EXTENDED_DEBUG = false
if IsInToolsMode() and PRINT_EXTENDED_DEBUG == true then require("common/adv_log") end
require("common/timers")
require("common/utils")
require("common/webapi/init")

require("common/disable_help")
require("common/smart_random")

require("common/items_limits")
require("common/block_holding_wards")
require("common/game_perks/game_perks_core")
require("common/voting_to_kick")
require("common/auto_team")
require("common/unique_portraits")
require("common/custom_chat")
require("common/toasts")
require("common/fountain_protection")
require("common/chat_wheel")
