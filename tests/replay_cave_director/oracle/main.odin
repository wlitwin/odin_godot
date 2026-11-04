package main
import "core:fmt"
import "core:os"
import oracle "../shared"

main :: proc() {
    failures := 0

    for scenario in oracle.CASES {
        report := oracle.compare(scenario)
        fmt.printf(
            "DIRECTOR_CASE name=%s mismatches=%d first_bad=%d old_spawns=%v new_spawns=%v old_done=%v new_done=%v\n",
            scenario.name,
            report.mismatches,
            report.first_bad,
            report.old_spawns[:report.old_count],
            report.new_spawns[:report.new_count],
            report.old_done,
            report.new_done,
        )
        failures += report.mismatches
    }

    for i in 0 ..< 256 {
        report := oracle.compare(oracle.matrix_case(i))
        failures += report.mismatches

        if report.mismatches > 0 {
            fmt.printf("DIRECTOR_MATRIX_FAIL case=%d first=%d count=%d\n", i, report.first_bad, report.mismatches)
        }
    }

    fmt.printf("DIRECTOR_MATRIX cases=256 mismatches=%d\n", failures)

    if failures > 0 {
        os.exit(1)
    }

    fmt.println("REPLAY_CAVE_DIRECTOR_ORACLE_OK")
}
