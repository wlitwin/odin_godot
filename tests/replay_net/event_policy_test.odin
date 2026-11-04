package replay_net_test

import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

@(test)
model_event_policy_survives_welcome_and_reconnect_without_early_gameplay_effects :: proc(t: ^testing.T) {
    for reconnect in 0 ..< 2 {
        f: Fixture
        fixture_init(&f)

        for &client in f.clients {
            client.model.event_policy = proc(event: Event) -> v.Policy {
                return .Confirmed
            }
        }

        for _ in 0 ..< 30 {
            fixture_step(&f)
        }

        client := &f.clients[0]

        if reconnect == 1 {
            before := client.view_reset
            tr.close(&client.wire)
            fixture_step(&f)
            testing.expect(t, tr.memory_open(&f.network, &f.endpoints[1], 2))
            net.client_reconnect(client, tr.memory_transport(&f.endpoints[1]))

            for _ in 0 ..< 30 {
                fixture_step(&f)
            }

            testing.expect(t, client.view_reset > before)
        }

        _, err := net.client_issue(client, Action{take = true})
        testing.expect_value(t, err, net.Error.None)
        net.client_step(client, Control{})
        changes: [512]v.Change(net.Net_Event(Event))
        n := v.drain(&client.journal, changes[:])

        for change in changes[:n] {
            testing.expect(t, change.kind != .Begin || change.occurrence.value.kind != .Gameplay)
        }

        begins := 0

        for _ in 0 ..< 90 {
            tr.memory_advance(&f.network, f.clock)
            now := f.clock * 1000 / 60
            net.server_pump(&f.server, now)

            for &c in f.clients {
                net.client_pump(&c, now)
            }

            net.server_step(&f.server)

            for &c, i in f.clients {
                if c.phase == .Running && !c.spectator {
                    net.client_step(&c, Control{})
                }

                for {
                    count := v.drain(&c.journal, changes[:])

                    if count == 0 {
                        break
                    }

                    for change in changes[:count] {
                        if i == 0 && change.kind == .Begin && change.occurrence.value.kind == .Gameplay {
                            begins += 1
                            testing.expect(t, change.confirmed)
                        }
                    }
                }
            }

            f.clock += 1
        }

        testing.expect_value(t, begins, 1)
        fixture_destroy(&f)
    }
}
