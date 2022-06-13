MatchEvents = MatchEvents or {}

MATCH_EVENT_DEFAULT_POLL_DELAY = IsInToolsMode() and 10 or 120
MATCH_EVENT_ACTIVE_POLL_DELAY = 5

MatchEvents.current_request_delay = MATCH_EVENT_DEFAULT_POLL_DELAY
MatchEvents.event_handlers = {}
-- status: complete, untested

function MatchEvents:ScheduleNextRequest()
	if MatchEvents.request_timer then Timers:RemoveTimer(MatchEvents.request_timer) end

	MatchEvents.request_timer = Timers:CreateTimer({
		useGameTime = false,
		endTime = MatchEvents.current_request_delay,
		callback = function() MatchEvents:SendRequest() end
	})
end


function MatchEvents:SendRequest()
	MatchEvents.request_timer = nil

	WebApi:Send(
		"match/events",
		{
			matchId = WebApi.matchId
		},
		function(events)
			MatchEvents:ScheduleNextRequest()
			for _, event in ipairs(events) do
				MatchEvents:HandleEvent(event)
			end
		end,
		function(err)
			print("[Match Events] failed request, rescheduling...")
			MatchEvents:ScheduleNextRequest()
		end
	)
end


function MatchEvents:HandleEvent(event)
	if not event.kind then
		error("[Match Events] no event kind in event body!")
	end

	local handler = MatchEvents.event_handlers[event.kind]

	if not handler then
		error("[Match Events] no handler for event of type " .. event.kind)
	end

	handler(event)
end


function MatchEvents:SetActivePolling(status)
	if status then
		MatchEvents.current_request_delay = MATCH_EVENT_ACTIVE_POLL_DELAY
	else
		MatchEvents.current_request_delay = MATCH_EVENT_DEFAULT_POLL_DELAY
	end

	MatchEvents:ScheduleNextRequest()
end
