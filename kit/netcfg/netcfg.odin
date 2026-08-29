package kit_netcfg

// kit/netcfg — named, coherent starting points for the complete network stack.
//
// A profile is not a security claim by itself. It chooses rates, time horizons,
// admission bounds, and simulation defaults that make sense together. The
// transport/authority model still determines whom the game trusts: in
// particular, Dedicated_Competitive only has its advertised trust boundary when
// the authority actually runs through boot_serve on infrastructure players do
// not control.
//
// Profiles return ordinary values. Start from one, then override the fields the
// game can justify:
//
//     cfg := network_profile(.Listen_Server_Action)
//     cfg.lane.smooth_cut = 48
//     cfg.lane.rewind_max = 30
//
// network_configure resolves the zero value to Friends_Coop, validates the
// complete pair, installs the session half, and returns the materialized config
// whose lane half can go straight to lane_init.

import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

Network_Profile :: enum u8 {
	Friends_Coop, // invited peers; owner streams and reliable shared state
	Listen_Server_Action, // a player-hosted authority; predict inputs, not outcomes
	Dedicated_Competitive, // an infrastructure authority; bounded adversarial inputs
}

// Engine-free benchmark-backed starting envelope. "Active" means dirty and in
// one recipient's AOI in the same tick; persistent entities may be much larger
// because sparse replication suppresses unchanged/out-of-interest rows.
Network_Profile_Envelope :: struct {
	players:                       int,
	replicated_entities:           int,
	active_entities_per_recipient: int,
	predicted_entities_per_client: int,
	max_resim_ticks:               int,
	snapshot_bytes_per_recipient:  int,
}

network_profile_envelope :: proc(profile: Network_Profile) -> Network_Profile_Envelope {
	switch profile {
	case .Friends_Coop:
		return {8, 2000, 500, 0, 0, 64 * 1024}
	case .Listen_Server_Action:
		return {8, 2000, 500, 128, 8, 32 * 1024}
	case .Dedicated_Competitive:
		return {8, 2000, 500, 512, 8, 24 * 1024}
	}
	unreachable()
}

Network_Config :: struct {
	profile: Network_Profile,
	session: ksess.Session_Config,
	lane:    ksim.Lane_Config,
}

// Facts the generated facade knows about the game rather than the values in
// Network_Config. Hand-wired games can pass the same facts explicitly.
Network_Capabilities :: struct {
	has_lane:             bool,
	all_inputs_validated: bool,
}

Network_Config_Error :: enum u8 {
	None,
	Session_Tick_Rate,
	Session_Interp_Delay,
	Session_Interp_Ceiling,
	Session_Command_Timeout,
	Session_Join_Timeout,
	Session_Backup_Interval,
	Session_Player_Limit,
	Session_Stream_Budget,
	Session_Traffic_Limit,
	Session_Traffic_Burst,
	Lane_Tick_Rate,
	Lane_Snapshot_Cadence,
	Lane_History,
	Lane_Margin,
	Lane_Redundancy,
	Lane_Rewind,
	Lane_Lead,
	Lane_Watch_Delay,
	Lane_Smoothing,
	Lane_Tolerance,
	Lane_Snapshot_Budget,
	Echo_Requires_Tolerance,
	Dedicated_Unbounded_Players,
	Dedicated_Fingerprint_Disabled,
	Dedicated_Input_Validator_Missing,
	Dedicated_Traffic_Unbounded,
}

// The zero profile deliberately reproduces Kit's existing zero-config behavior
// exactly. The other two make their latency and trust tradeoffs explicit.
network_profile :: proc(profile := Network_Profile.Friends_Coop) -> Network_Config {
	switch profile {
	case .Friends_Coop:
		return {
			profile = profile,
			session = {
				tick_hz = knet.DEFAULT_TICK_HZ,
				interp_delay = 0.15,
				interp_adapt = false,
				interp_delay_max = 0.60,
				command_timeout = 3.0,
				join_timeout = 15.0,
				backup_interval = 5.0,
				max_players = 8,
				change_events = false,
				stream_budget = 0,
				traffic = {
					reliable = {packets_per_second = 512, bytes_per_second = 2 * 1024 * 1024, burst_seconds = 2},
					stream   = {packets_per_second = 240, bytes_per_second = 2 * 1024 * 1024, burst_seconds = 1},
					actions  = {packets_per_second = 64, bytes_per_second = 256 * 1024, burst_seconds = 1},
				},
				fingerprint = 0,
			},
			lane = {
				hz = 60,
				snap_every = 3,
				slots = 128,
				margin = 2,
				redundancy = 8,
				rewind_max = 15,
				lead_max = 64,
				watch_delay = 6,
				smooth_halflife = 0.063,
				smooth_cut = 0,
				judge_live = false,
				echo_inputs = false,
				tolerance = 0,
				snapshot_budget = network_profile_envelope(profile).snapshot_bytes_per_recipient,
			},
		}
	case .Listen_Server_Action:
		return {
			profile = profile,
			session = {
				tick_hz = 20,
				interp_delay = 0.15,
				interp_adapt = true,
				interp_delay_max = 0.40,
				command_timeout = 2.0,
				join_timeout = 12.0,
				backup_interval = 3.0,
				max_players = 8,
				change_events = false,
				stream_budget = 0,
				traffic = {
					reliable = {packets_per_second = 256, bytes_per_second = 1024 * 1024, burst_seconds = 2},
					stream   = {packets_per_second = 240, bytes_per_second = 2 * 1024 * 1024, burst_seconds = 1},
					actions  = {packets_per_second = 60, bytes_per_second = 256 * 1024, burst_seconds = 1},
				},
				fingerprint = 0,
			},
			lane = {
				hz = 60,
				snap_every = 3,
				slots = 128,
				margin = 2,
				redundancy = 8,
				rewind_max = 24,
				lead_max = 64,
				watch_delay = 6,
				smooth_halflife = 0.063,
				smooth_cut = 0,
				judge_live = false,
				echo_inputs = false,
				tolerance = 0,
				snapshot_budget = network_profile_envelope(profile).snapshot_bytes_per_recipient,
			},
		}
	case .Dedicated_Competitive:
		return {
			profile = profile,
			session = {
				tick_hz = 20,
				interp_delay = 0.10,
				interp_adapt = true,
				interp_delay_max = 0.25,
				command_timeout = 1.5,
				join_timeout = 10.0,
				backup_interval = 5.0,
				max_players = 8,
				change_events = false,
				stream_budget = 0,
				traffic = {
					reliable = {packets_per_second = 128, bytes_per_second = 512 * 1024, burst_seconds = 1},
					stream   = {packets_per_second = 120, bytes_per_second = 1024 * 1024, burst_seconds = 1},
					actions  = {packets_per_second = 30, bytes_per_second = 128 * 1024, burst_seconds = 1},
				},
				fingerprint = 0,
			},
			lane = {
				hz = 60,
				snap_every = 2,
				slots = 128,
				margin = 3,
				redundancy = 8,
				rewind_max = 15,
				lead_max = 24,
				watch_delay = 4,
				smooth_halflife = 0.050,
				smooth_cut = 0,
				judge_live = false,
				echo_inputs = false,
				tolerance = 0,
				snapshot_budget = network_profile_envelope(profile).snapshot_bytes_per_recipient,
			},
		}
	}
	unreachable()
}

// An omitted third argument on a generated attach arrives as an all-zero
// Network_Config. Resolve only that complete zero value; a partial literal is
// intentionally rejected instead of silently mixing profile and zero-default
// semantics. This keeps overrides obvious: obtain a profile value, then edit it.
network_config_resolve :: proc(cfg: Network_Config) -> Network_Config {
	if cfg == (Network_Config{}) {
		return network_profile(.Friends_Coop)
	}
	return cfg
}

network_config_check :: proc(
	raw: Network_Config,
	caps := Network_Capabilities{},
) -> Network_Config_Error {
	cfg := network_config_resolve(raw)
	s := cfg.session
	if s.tick_hz <= 0 {return .Session_Tick_Rate}
	if s.interp_delay <= 0 {return .Session_Interp_Delay}
	if s.interp_delay_max <= 0 || (s.interp_adapt && s.interp_delay_max < s.interp_delay) {
		return .Session_Interp_Ceiling
	}
	if s.command_timeout <= 0 {return .Session_Command_Timeout}
	if s.join_timeout <= 0 {return .Session_Join_Timeout}
	if s.backup_interval <= 0 {return .Session_Backup_Interval}
	if s.max_players == 0 {return .Session_Player_Limit}
	if s.stream_budget < 0 {return .Session_Stream_Budget}
	traffic_limits := [?]ksess.Traffic_Limit{s.traffic.reliable, s.traffic.stream, s.traffic.actions}
	for limit in traffic_limits {
		if limit.packets_per_second < 0 || limit.bytes_per_second < 0 {
			return .Session_Traffic_Limit
		}
		if limit.burst_seconds < 0 {
			return .Session_Traffic_Burst
		}
	}

	if caps.has_lane {
		l := cfg.lane
		if l.hz <= 0 {return .Lane_Tick_Rate}
		if l.snap_every <= 0 {return .Lane_Snapshot_Cadence}
		if l.slots < 2 || l.snap_every >= l.slots {return .Lane_History}
		if l.margin <= 0 || l.margin >= l.slots {return .Lane_Margin}
		if l.redundancy <= 0 ||
		   l.redundancy > ksim.MAX_INPUT_REDUNDANCY ||
		   l.redundancy > l.slots {
			return .Lane_Redundancy
		}
		if l.rewind_max <= 0 || l.rewind_max >= l.slots {return .Lane_Rewind}
		if l.lead_max <= 0 || l.lead_max >= l.slots {return .Lane_Lead}
		if l.watch_delay <= 0 || l.watch_delay > 31 || l.watch_delay >= l.slots {
			return .Lane_Watch_Delay
		}
		if l.smooth_halflife <= 0 || l.smooth_cut < 0 {return .Lane_Smoothing}
		if l.tolerance < 0 {return .Lane_Tolerance}
		if l.snapshot_budget < 0 || (l.snapshot_budget > 0 && l.snapshot_budget < ksim.SNAP_HEADER_BYTES) {
			return .Lane_Snapshot_Budget
		}
		if l.echo_inputs && l.tolerance <= 0 {return .Echo_Requires_Tolerance}
	}

	if cfg.profile == .Dedicated_Competitive {
		if s.max_players < 0 {return .Dedicated_Unbounded_Players}
		if s.fingerprint == ksess.FINGERPRINT_NONE {return .Dedicated_Fingerprint_Disabled}
		if caps.has_lane && !caps.all_inputs_validated {
			return .Dedicated_Input_Validator_Missing
		}
		for limit in traffic_limits {
			if limit.packets_per_second == 0 || limit.bytes_per_second == 0 {
				return .Dedicated_Traffic_Unbounded
			}
		}
	}
	return .None
}

network_config_error :: proc(err: Network_Config_Error) -> string {
	switch err {
	case .None:
		return ""
	case .Session_Tick_Rate:
		return "network config: session.tick_hz must be positive"
	case .Session_Interp_Delay:
		return "network config: session.interp_delay must be positive"
	case .Session_Interp_Ceiling:
		return(
			"network config: session.interp_delay_max must be positive and no lower than an adaptive interp_delay" \
		)
	case .Session_Command_Timeout:
		return "network config: session.command_timeout must be positive"
	case .Session_Join_Timeout:
		return "network config: session.join_timeout must be positive"
	case .Session_Backup_Interval:
		return "network config: session.backup_interval must be positive"
	case .Session_Player_Limit:
		return(
			"network config: session.max_players must be positive, or negative only for an intentional unbounded custom lobby" \
		)
	case .Session_Stream_Budget:
		return "network config: session.stream_budget cannot be negative"
	case .Session_Traffic_Limit:
		return "network config: session traffic packet and byte rates cannot be negative"
	case .Session_Traffic_Burst:
		return "network config: session traffic burst_seconds cannot be negative"
	case .Lane_Tick_Rate:
		return "network config: lane.hz must be positive"
	case .Lane_Snapshot_Cadence:
		return "network config: lane.snap_every must be positive"
	case .Lane_History:
		return "network config: lane.slots must hold the snapshot cadence and at least two ticks"
	case .Lane_Margin:
		return "network config: lane.margin must be positive and fit inside lane.slots"
	case .Lane_Redundancy:
		return(
			"network config: lane.redundancy must be positive and fit the receiver and history bounds" \
		)
	case .Lane_Rewind:
		return "network config: lane.rewind_max must be positive and fit inside lane.slots"
	case .Lane_Lead:
		return "network config: lane.lead_max must be positive and fit inside lane.slots"
	case .Lane_Watch_Delay:
		return "network config: lane.watch_delay must be 1..31 ticks and fit inside lane.slots"
	case .Lane_Smoothing:
		return(
			"network config: lane.smooth_halflife must be positive and smooth_cut cannot be negative" \
		)
	case .Lane_Tolerance:
		return "network config: lane.tolerance cannot be negative"
	case .Lane_Snapshot_Budget:
		return "network config: lane.snapshot_budget must be zero or fit the fixed snapshot header"
	case .Echo_Requires_Tolerance:
		return(
			"network config: echo_inputs needs a positive tolerance; exact held-input comparison resimulates nearly every batch" \
		)
	case .Dedicated_Unbounded_Players:
		return "Dedicated_Competitive requires a bounded session.max_players"
	case .Dedicated_Fingerprint_Disabled:
		return "Dedicated_Competitive cannot disable the generated wire fingerprint gate"
	case .Dedicated_Input_Validator_Missing:
		return(
			"Dedicated_Competitive requires @(gd_input) field constraints or @(gd_sample=\"validate\") on every network input class" \
		)
	case .Dedicated_Traffic_Unbounded:
		return "Dedicated_Competitive requires packet and byte limits for reliable, stream, and action ingress"
	}
	return "network config: unknown validation error"
}

network_configure :: proc(
	s: ^ksess.Session,
	raw: Network_Config,
	caps := Network_Capabilities{},
) -> Network_Config {
	cfg := network_config_resolve(raw)
	err := network_config_check(cfg, caps)
	assert(err == .None, network_config_error(err))
	ksess.session_configure(s, cfg.session)
	return cfg
}
