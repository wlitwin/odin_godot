package caller_values

import containers "../containers"

Local_Type :: struct { axis: i32 }
Number :: i16
Mode :: enum u16 { First, Second }
Sample_Input :: containers.Numeric_Input(Number, 2, Mode)
Vector :: [2]f32
Vector_Input :: containers.Vector_Input(Vector)
