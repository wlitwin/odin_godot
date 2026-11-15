# Deterministic arithmetic

`Fixed` is a signed 32-bit Q24.8 value: 256 units represent one world unit.
`from_int`, `add`, `sub`, `mul` and `div` use fixed-width intermediates and return
an explicit success flag. Multiplication/division truncate toward zero; overflow
and division by zero return no valid result. Do not ignore failures in simulation.

`overlap` compares AABBs, `circles_overlap` compares squared distances without an
overflowing squared sum, and `isqrt` returns the floor of a u64 square root.
These helpers do not read clocks or allocate. Rendering can convert to floats
outside simulation.

The integer duel additionally constrains its coordinate/counter ranges, updates
entities in stable slot order and stores RNG/allocation/lifetime in the world.
Its canonical state/event corpus executes identically on native arm64 and WASM.
That evidence applies to the tested model/corpus; fixed-point types alone do not
prove an arbitrary game, compiler version or platform deterministic.
