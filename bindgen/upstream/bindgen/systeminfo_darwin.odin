#+build darwin
package bindgen

import "core:os"

num_processors :: proc() -> int {
    return os.get_processor_core_count()
}
