package director_wasm
import "base:runtime"
import oracle "../shared"

@(export)
compare :: proc "c" (index: u32) -> u32 {
    context = runtime.default_context()

    if index < 6 {
        cases := oracle.CASES
        report := oracle.compare(cases[index])
        return u32(report.mismatches)
    }

    if index < 262 {
        report := oracle.compare(oracle.matrix_case(int(index) - 6))
        return u32(report.mismatches)
    }

    return max(u32)
}
