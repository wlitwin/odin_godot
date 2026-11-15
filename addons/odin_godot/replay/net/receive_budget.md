# Receive budgets preserve complete packets

Client and server pumps pass only their remaining byte allowance to
`transport.receive`. If the next complete packet does not fit, the transport
returns `Buffer_Too_Small` and retains it. The pump stops and tries again with a
fresh allowance next time. An exactly exhausted budget stops before another read.
Packet count and byte limits are unchanged.

Before the receive-budget fix, loops read into the full 64 KiB buffer and checked the budget only
after dequeueing. The crossing packet was then discarded, even on a reliable
channel. Reliability cannot recover a packet already accepted and removed from
the transport's receive queue. Large actions could stall until application retry;
large fact batches could leave observer event history incomplete.

Every legal packet fits a fresh pump: `transport.MAX_PACKET_BYTES` is 65,536, and
network configuration already requires `bytes_per_pump >= 65,536`. This uses
the existing receive-retention contract and existing buffers, queue bounds, byte
budgets and retry paths. `Buffer_Too_Small` is not a
malformed-packet rejection. Authority traffic counters still count successfully
received authority packets; client traffic from other senders consumes the work
budget before being rejected, without being attributed to the authority.

All transport adapters must retain data on a short destination, including wrappers.
Their bounded internal polling/queues remain separate from the application's
per-pump dispatch allowance. A retained packet still undergoes the usual scope,
generation, epoch, admission and content checks when received. This change does
not promise delivery across a disconnected or expired binding.

The regression suite uses authentic generated protocol packets. At the minimum
byte budget, three large fact batches previously yielded only 32 of 96 observer
effects; now all 96 arrive once. Two large action submissions previously applied
only the first; now both apply without any additional client pump or resend.
Each pump stays within its byte budget. Unknown senders and exact exhaustion are
also checked. Real ENet and Chrome RTC probes exercise short-buffer retention,
metadata/payload integrity, both channels, replacement and adapter restart.

This independent defect was found while investigating the older Claimball C2
observer-effect failure. The historical failure has no captured delivery schedule,
and its cause remains unestablished. A current fault run with complete effects and
strict replay is a regression check, not retrospective proof of that cause.
