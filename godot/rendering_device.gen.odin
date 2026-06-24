package godot

import __bindgen_gde "godot:gdext"

Rendering_Device_Constants :: enum {
    INVALID_ID = -1,
    INVALID_FORMAT_ID = -1,
}
Rendering_Device_Device_Type :: enum int {
    Device_Type_Other = 0,
    Device_Type_Integrated_Gpu = 1,
    Device_Type_Discrete_Gpu = 2,
    Device_Type_Virtual_Gpu = 3,
    Device_Type_Cpu = 4,
    Device_Type_Max = 5,
}
Rendering_Device_Driver_Resource :: enum int {
    Driver_Resource_Logical_Device = 0,
    Driver_Resource_Physical_Device = 1,
    Driver_Resource_Topmost_Object = 2,
    Driver_Resource_Command_Queue = 3,
    Driver_Resource_Queue_Family = 4,
    Driver_Resource_Texture = 5,
    Driver_Resource_Texture_View = 6,
    Driver_Resource_Texture_Data_Format = 7,
    Driver_Resource_Sampler = 8,
    Driver_Resource_Uniform_Set = 9,
    Driver_Resource_Buffer = 10,
    Driver_Resource_Compute_Pipeline = 11,
    Driver_Resource_Render_Pipeline = 12,
    Driver_Resource_Vulkan_Device = 0,
    Driver_Resource_Vulkan_Physical_Device = 1,
    Driver_Resource_Vulkan_Instance = 2,
    Driver_Resource_Vulkan_Queue = 3,
    Driver_Resource_Vulkan_Queue_Family_Index = 4,
    Driver_Resource_Vulkan_Image = 5,
    Driver_Resource_Vulkan_Image_View = 6,
    Driver_Resource_Vulkan_Image_Native_Texture_Format = 7,
    Driver_Resource_Vulkan_Sampler = 8,
    Driver_Resource_Vulkan_Descriptor_Set = 9,
    Driver_Resource_Vulkan_Buffer = 10,
    Driver_Resource_Vulkan_Compute_Pipeline = 11,
    Driver_Resource_Vulkan_Render_Pipeline = 12,
}
Rendering_Device_Data_Format :: enum int {
    Data_Format_R4g4_Unorm_Pack8 = 0,
    Data_Format_R4g4b4a4_Unorm_Pack16 = 1,
    Data_Format_B4g4r4a4_Unorm_Pack16 = 2,
    Data_Format_R5g6b5_Unorm_Pack16 = 3,
    Data_Format_B5g6r5_Unorm_Pack16 = 4,
    Data_Format_R5g5b5a1_Unorm_Pack16 = 5,
    Data_Format_B5g5r5a1_Unorm_Pack16 = 6,
    Data_Format_A1r5g5b5_Unorm_Pack16 = 7,
    Data_Format_R8_Unorm = 8,
    Data_Format_R8_Snorm = 9,
    Data_Format_R8_Uscaled = 10,
    Data_Format_R8_Sscaled = 11,
    Data_Format_R8_Uint = 12,
    Data_Format_R8_Sint = 13,
    Data_Format_R8_Srgb = 14,
    Data_Format_R8g8_Unorm = 15,
    Data_Format_R8g8_Snorm = 16,
    Data_Format_R8g8_Uscaled = 17,
    Data_Format_R8g8_Sscaled = 18,
    Data_Format_R8g8_Uint = 19,
    Data_Format_R8g8_Sint = 20,
    Data_Format_R8g8_Srgb = 21,
    Data_Format_R8g8b8_Unorm = 22,
    Data_Format_R8g8b8_Snorm = 23,
    Data_Format_R8g8b8_Uscaled = 24,
    Data_Format_R8g8b8_Sscaled = 25,
    Data_Format_R8g8b8_Uint = 26,
    Data_Format_R8g8b8_Sint = 27,
    Data_Format_R8g8b8_Srgb = 28,
    Data_Format_B8g8r8_Unorm = 29,
    Data_Format_B8g8r8_Snorm = 30,
    Data_Format_B8g8r8_Uscaled = 31,
    Data_Format_B8g8r8_Sscaled = 32,
    Data_Format_B8g8r8_Uint = 33,
    Data_Format_B8g8r8_Sint = 34,
    Data_Format_B8g8r8_Srgb = 35,
    Data_Format_R8g8b8a8_Unorm = 36,
    Data_Format_R8g8b8a8_Snorm = 37,
    Data_Format_R8g8b8a8_Uscaled = 38,
    Data_Format_R8g8b8a8_Sscaled = 39,
    Data_Format_R8g8b8a8_Uint = 40,
    Data_Format_R8g8b8a8_Sint = 41,
    Data_Format_R8g8b8a8_Srgb = 42,
    Data_Format_B8g8r8a8_Unorm = 43,
    Data_Format_B8g8r8a8_Snorm = 44,
    Data_Format_B8g8r8a8_Uscaled = 45,
    Data_Format_B8g8r8a8_Sscaled = 46,
    Data_Format_B8g8r8a8_Uint = 47,
    Data_Format_B8g8r8a8_Sint = 48,
    Data_Format_B8g8r8a8_Srgb = 49,
    Data_Format_A8b8g8r8_Unorm_Pack32 = 50,
    Data_Format_A8b8g8r8_Snorm_Pack32 = 51,
    Data_Format_A8b8g8r8_Uscaled_Pack32 = 52,
    Data_Format_A8b8g8r8_Sscaled_Pack32 = 53,
    Data_Format_A8b8g8r8_Uint_Pack32 = 54,
    Data_Format_A8b8g8r8_Sint_Pack32 = 55,
    Data_Format_A8b8g8r8_Srgb_Pack32 = 56,
    Data_Format_A2r10g10b10_Unorm_Pack32 = 57,
    Data_Format_A2r10g10b10_Snorm_Pack32 = 58,
    Data_Format_A2r10g10b10_Uscaled_Pack32 = 59,
    Data_Format_A2r10g10b10_Sscaled_Pack32 = 60,
    Data_Format_A2r10g10b10_Uint_Pack32 = 61,
    Data_Format_A2r10g10b10_Sint_Pack32 = 62,
    Data_Format_A2b10g10r10_Unorm_Pack32 = 63,
    Data_Format_A2b10g10r10_Snorm_Pack32 = 64,
    Data_Format_A2b10g10r10_Uscaled_Pack32 = 65,
    Data_Format_A2b10g10r10_Sscaled_Pack32 = 66,
    Data_Format_A2b10g10r10_Uint_Pack32 = 67,
    Data_Format_A2b10g10r10_Sint_Pack32 = 68,
    Data_Format_R16_Unorm = 69,
    Data_Format_R16_Snorm = 70,
    Data_Format_R16_Uscaled = 71,
    Data_Format_R16_Sscaled = 72,
    Data_Format_R16_Uint = 73,
    Data_Format_R16_Sint = 74,
    Data_Format_R16_Sfloat = 75,
    Data_Format_R16g16_Unorm = 76,
    Data_Format_R16g16_Snorm = 77,
    Data_Format_R16g16_Uscaled = 78,
    Data_Format_R16g16_Sscaled = 79,
    Data_Format_R16g16_Uint = 80,
    Data_Format_R16g16_Sint = 81,
    Data_Format_R16g16_Sfloat = 82,
    Data_Format_R16g16b16_Unorm = 83,
    Data_Format_R16g16b16_Snorm = 84,
    Data_Format_R16g16b16_Uscaled = 85,
    Data_Format_R16g16b16_Sscaled = 86,
    Data_Format_R16g16b16_Uint = 87,
    Data_Format_R16g16b16_Sint = 88,
    Data_Format_R16g16b16_Sfloat = 89,
    Data_Format_R16g16b16a16_Unorm = 90,
    Data_Format_R16g16b16a16_Snorm = 91,
    Data_Format_R16g16b16a16_Uscaled = 92,
    Data_Format_R16g16b16a16_Sscaled = 93,
    Data_Format_R16g16b16a16_Uint = 94,
    Data_Format_R16g16b16a16_Sint = 95,
    Data_Format_R16g16b16a16_Sfloat = 96,
    Data_Format_R32_Uint = 97,
    Data_Format_R32_Sint = 98,
    Data_Format_R32_Sfloat = 99,
    Data_Format_R32g32_Uint = 100,
    Data_Format_R32g32_Sint = 101,
    Data_Format_R32g32_Sfloat = 102,
    Data_Format_R32g32b32_Uint = 103,
    Data_Format_R32g32b32_Sint = 104,
    Data_Format_R32g32b32_Sfloat = 105,
    Data_Format_R32g32b32a32_Uint = 106,
    Data_Format_R32g32b32a32_Sint = 107,
    Data_Format_R32g32b32a32_Sfloat = 108,
    Data_Format_R64_Uint = 109,
    Data_Format_R64_Sint = 110,
    Data_Format_R64_Sfloat = 111,
    Data_Format_R64g64_Uint = 112,
    Data_Format_R64g64_Sint = 113,
    Data_Format_R64g64_Sfloat = 114,
    Data_Format_R64g64b64_Uint = 115,
    Data_Format_R64g64b64_Sint = 116,
    Data_Format_R64g64b64_Sfloat = 117,
    Data_Format_R64g64b64a64_Uint = 118,
    Data_Format_R64g64b64a64_Sint = 119,
    Data_Format_R64g64b64a64_Sfloat = 120,
    Data_Format_B10g11r11_Ufloat_Pack32 = 121,
    Data_Format_E5b9g9r9_Ufloat_Pack32 = 122,
    Data_Format_D16_Unorm = 123,
    Data_Format_X8_D24_Unorm_Pack32 = 124,
    Data_Format_D32_Sfloat = 125,
    Data_Format_S8_Uint = 126,
    Data_Format_D16_Unorm_S8_Uint = 127,
    Data_Format_D24_Unorm_S8_Uint = 128,
    Data_Format_D32_Sfloat_S8_Uint = 129,
    Data_Format_Bc1_Rgb_Unorm_Block = 130,
    Data_Format_Bc1_Rgb_Srgb_Block = 131,
    Data_Format_Bc1_Rgba_Unorm_Block = 132,
    Data_Format_Bc1_Rgba_Srgb_Block = 133,
    Data_Format_Bc2_Unorm_Block = 134,
    Data_Format_Bc2_Srgb_Block = 135,
    Data_Format_Bc3_Unorm_Block = 136,
    Data_Format_Bc3_Srgb_Block = 137,
    Data_Format_Bc4_Unorm_Block = 138,
    Data_Format_Bc4_Snorm_Block = 139,
    Data_Format_Bc5_Unorm_Block = 140,
    Data_Format_Bc5_Snorm_Block = 141,
    Data_Format_Bc6h_Ufloat_Block = 142,
    Data_Format_Bc6h_Sfloat_Block = 143,
    Data_Format_Bc7_Unorm_Block = 144,
    Data_Format_Bc7_Srgb_Block = 145,
    Data_Format_Etc2_R8g8b8_Unorm_Block = 146,
    Data_Format_Etc2_R8g8b8_Srgb_Block = 147,
    Data_Format_Etc2_R8g8b8a1_Unorm_Block = 148,
    Data_Format_Etc2_R8g8b8a1_Srgb_Block = 149,
    Data_Format_Etc2_R8g8b8a8_Unorm_Block = 150,
    Data_Format_Etc2_R8g8b8a8_Srgb_Block = 151,
    Data_Format_Eac_R11_Unorm_Block = 152,
    Data_Format_Eac_R11_Snorm_Block = 153,
    Data_Format_Eac_R11g11_Unorm_Block = 154,
    Data_Format_Eac_R11g11_Snorm_Block = 155,
    Data_Format_Astc_4x4_Unorm_Block = 156,
    Data_Format_Astc_4x4_Srgb_Block = 157,
    Data_Format_Astc_5x4_Unorm_Block = 158,
    Data_Format_Astc_5x4_Srgb_Block = 159,
    Data_Format_Astc_5x5_Unorm_Block = 160,
    Data_Format_Astc_5x5_Srgb_Block = 161,
    Data_Format_Astc_6x5_Unorm_Block = 162,
    Data_Format_Astc_6x5_Srgb_Block = 163,
    Data_Format_Astc_6x6_Unorm_Block = 164,
    Data_Format_Astc_6x6_Srgb_Block = 165,
    Data_Format_Astc_8x5_Unorm_Block = 166,
    Data_Format_Astc_8x5_Srgb_Block = 167,
    Data_Format_Astc_8x6_Unorm_Block = 168,
    Data_Format_Astc_8x6_Srgb_Block = 169,
    Data_Format_Astc_8x8_Unorm_Block = 170,
    Data_Format_Astc_8x8_Srgb_Block = 171,
    Data_Format_Astc_10x5_Unorm_Block = 172,
    Data_Format_Astc_10x5_Srgb_Block = 173,
    Data_Format_Astc_10x6_Unorm_Block = 174,
    Data_Format_Astc_10x6_Srgb_Block = 175,
    Data_Format_Astc_10x8_Unorm_Block = 176,
    Data_Format_Astc_10x8_Srgb_Block = 177,
    Data_Format_Astc_10x10_Unorm_Block = 178,
    Data_Format_Astc_10x10_Srgb_Block = 179,
    Data_Format_Astc_12x10_Unorm_Block = 180,
    Data_Format_Astc_12x10_Srgb_Block = 181,
    Data_Format_Astc_12x12_Unorm_Block = 182,
    Data_Format_Astc_12x12_Srgb_Block = 183,
    Data_Format_G8b8g8r8_422_Unorm = 184,
    Data_Format_B8g8r8g8_422_Unorm = 185,
    Data_Format_G8_B8_R8_3plane_420_Unorm = 186,
    Data_Format_G8_B8r8_2plane_420_Unorm = 187,
    Data_Format_G8_B8_R8_3plane_422_Unorm = 188,
    Data_Format_G8_B8r8_2plane_422_Unorm = 189,
    Data_Format_G8_B8_R8_3plane_444_Unorm = 190,
    Data_Format_R10x6_Unorm_Pack16 = 191,
    Data_Format_R10x6g10x6_Unorm_2pack16 = 192,
    Data_Format_R10x6g10x6b10x6a10x6_Unorm_4pack16 = 193,
    Data_Format_G10x6b10x6g10x6r10x6_422_Unorm_4pack16 = 194,
    Data_Format_B10x6g10x6r10x6g10x6_422_Unorm_4pack16 = 195,
    Data_Format_G10x6_B10x6_R10x6_3plane_420_Unorm_3pack16 = 196,
    Data_Format_G10x6_B10x6r10x6_2plane_420_Unorm_3pack16 = 197,
    Data_Format_G10x6_B10x6_R10x6_3plane_422_Unorm_3pack16 = 198,
    Data_Format_G10x6_B10x6r10x6_2plane_422_Unorm_3pack16 = 199,
    Data_Format_G10x6_B10x6_R10x6_3plane_444_Unorm_3pack16 = 200,
    Data_Format_R12x4_Unorm_Pack16 = 201,
    Data_Format_R12x4g12x4_Unorm_2pack16 = 202,
    Data_Format_R12x4g12x4b12x4a12x4_Unorm_4pack16 = 203,
    Data_Format_G12x4b12x4g12x4r12x4_422_Unorm_4pack16 = 204,
    Data_Format_B12x4g12x4r12x4g12x4_422_Unorm_4pack16 = 205,
    Data_Format_G12x4_B12x4_R12x4_3plane_420_Unorm_3pack16 = 206,
    Data_Format_G12x4_B12x4r12x4_2plane_420_Unorm_3pack16 = 207,
    Data_Format_G12x4_B12x4_R12x4_3plane_422_Unorm_3pack16 = 208,
    Data_Format_G12x4_B12x4r12x4_2plane_422_Unorm_3pack16 = 209,
    Data_Format_G12x4_B12x4_R12x4_3plane_444_Unorm_3pack16 = 210,
    Data_Format_G16b16g16r16_422_Unorm = 211,
    Data_Format_B16g16r16g16_422_Unorm = 212,
    Data_Format_G16_B16_R16_3plane_420_Unorm = 213,
    Data_Format_G16_B16r16_2plane_420_Unorm = 214,
    Data_Format_G16_B16_R16_3plane_422_Unorm = 215,
    Data_Format_G16_B16r16_2plane_422_Unorm = 216,
    Data_Format_G16_B16_R16_3plane_444_Unorm = 217,
    Data_Format_Astc_4x4_Sfloat_Block = 218,
    Data_Format_Astc_5x4_Sfloat_Block = 219,
    Data_Format_Astc_5x5_Sfloat_Block = 220,
    Data_Format_Astc_6x5_Sfloat_Block = 221,
    Data_Format_Astc_6x6_Sfloat_Block = 222,
    Data_Format_Astc_8x5_Sfloat_Block = 223,
    Data_Format_Astc_8x6_Sfloat_Block = 224,
    Data_Format_Astc_8x8_Sfloat_Block = 225,
    Data_Format_Astc_10x5_Sfloat_Block = 226,
    Data_Format_Astc_10x6_Sfloat_Block = 227,
    Data_Format_Astc_10x8_Sfloat_Block = 228,
    Data_Format_Astc_10x10_Sfloat_Block = 229,
    Data_Format_Astc_12x10_Sfloat_Block = 230,
    Data_Format_Astc_12x12_Sfloat_Block = 231,
    Data_Format_Max = 232,
}
Rendering_Device_Texture_Type :: enum int {
    Texture_Type_1d = 0,
    Texture_Type_2d = 1,
    Texture_Type_3d = 2,
    Texture_Type_Cube = 3,
    Texture_Type_1d_Array = 4,
    Texture_Type_2d_Array = 5,
    Texture_Type_Cube_Array = 6,
    Texture_Type_Max = 7,
}
Rendering_Device_Texture_Samples :: enum int {
    Texture_Samples_1 = 0,
    Texture_Samples_2 = 1,
    Texture_Samples_4 = 2,
    Texture_Samples_8 = 3,
    Texture_Samples_16 = 4,
    Texture_Samples_32 = 5,
    Texture_Samples_64 = 6,
    Texture_Samples_Max = 7,
}
Rendering_Device_Texture_Swizzle :: enum int {
    Texture_Swizzle_Identity = 0,
    Texture_Swizzle_Zero = 1,
    Texture_Swizzle_One = 2,
    Texture_Swizzle_R = 3,
    Texture_Swizzle_G = 4,
    Texture_Swizzle_B = 5,
    Texture_Swizzle_A = 6,
    Texture_Swizzle_Max = 7,
}
Rendering_Device_Texture_Slice_Type :: enum int {
    Texture_Slice_2d = 0,
    Texture_Slice_Cubemap = 1,
    Texture_Slice_3d = 2,
}
Rendering_Device_Sampler_Filter :: enum int {
    Sampler_Filter_Nearest = 0,
    Sampler_Filter_Linear = 1,
}
Rendering_Device_Sampler_Repeat_Mode :: enum int {
    Sampler_Repeat_Mode_Repeat = 0,
    Sampler_Repeat_Mode_Mirrored_Repeat = 1,
    Sampler_Repeat_Mode_Clamp_To_Edge = 2,
    Sampler_Repeat_Mode_Clamp_To_Border = 3,
    Sampler_Repeat_Mode_Mirror_Clamp_To_Edge = 4,
    Sampler_Repeat_Mode_Max = 5,
}
Rendering_Device_Sampler_Border_Color :: enum int {
    Sampler_Border_Color_Float_Transparent_Black = 0,
    Sampler_Border_Color_Int_Transparent_Black = 1,
    Sampler_Border_Color_Float_Opaque_Black = 2,
    Sampler_Border_Color_Int_Opaque_Black = 3,
    Sampler_Border_Color_Float_Opaque_White = 4,
    Sampler_Border_Color_Int_Opaque_White = 5,
    Sampler_Border_Color_Max = 6,
}
Rendering_Device_Vertex_Frequency :: enum int {
    Vertex_Frequency_Vertex = 0,
    Vertex_Frequency_Instance = 1,
}
Rendering_Device_Index_Buffer_Format :: enum int {
    Index_Buffer_Format_Uint16 = 0,
    Index_Buffer_Format_Uint32 = 1,
}
Rendering_Device_Uniform_Type :: enum int {
    Uniform_Type_Sampler = 0,
    Uniform_Type_Sampler_With_Texture = 1,
    Uniform_Type_Texture = 2,
    Uniform_Type_Image = 3,
    Uniform_Type_Texture_Buffer = 4,
    Uniform_Type_Sampler_With_Texture_Buffer = 5,
    Uniform_Type_Image_Buffer = 6,
    Uniform_Type_Uniform_Buffer = 7,
    Uniform_Type_Storage_Buffer = 8,
    Uniform_Type_Input_Attachment = 9,
    Uniform_Type_Uniform_Buffer_Dynamic = 10,
    Uniform_Type_Storage_Buffer_Dynamic = 11,
    Uniform_Type_Max = 12,
}
Rendering_Device_Render_Primitive :: enum int {
    Render_Primitive_Points = 0,
    Render_Primitive_Lines = 1,
    Render_Primitive_Lines_With_Adjacency = 2,
    Render_Primitive_Linestrips = 3,
    Render_Primitive_Linestrips_With_Adjacency = 4,
    Render_Primitive_Triangles = 5,
    Render_Primitive_Triangles_With_Adjacency = 6,
    Render_Primitive_Triangle_Strips = 7,
    Render_Primitive_Triangle_Strips_With_Ajacency = 8,
    Render_Primitive_Triangle_Strips_With_Restart_Index = 9,
    Render_Primitive_Tesselation_Patch = 10,
    Render_Primitive_Max = 11,
}
Rendering_Device_Polygon_Cull_Mode :: enum int {
    Polygon_Cull_Disabled = 0,
    Polygon_Cull_Front = 1,
    Polygon_Cull_Back = 2,
}
Rendering_Device_Polygon_Front_Face :: enum int {
    Polygon_Front_Face_Clockwise = 0,
    Polygon_Front_Face_Counter_Clockwise = 1,
}
Rendering_Device_Stencil_Operation :: enum int {
    Stencil_Op_Keep = 0,
    Stencil_Op_Zero = 1,
    Stencil_Op_Replace = 2,
    Stencil_Op_Increment_And_Clamp = 3,
    Stencil_Op_Decrement_And_Clamp = 4,
    Stencil_Op_Invert = 5,
    Stencil_Op_Increment_And_Wrap = 6,
    Stencil_Op_Decrement_And_Wrap = 7,
    Stencil_Op_Max = 8,
}
Rendering_Device_Compare_Operator :: enum int {
    Compare_Op_Never = 0,
    Compare_Op_Less = 1,
    Compare_Op_Equal = 2,
    Compare_Op_Less_Or_Equal = 3,
    Compare_Op_Greater = 4,
    Compare_Op_Not_Equal = 5,
    Compare_Op_Greater_Or_Equal = 6,
    Compare_Op_Always = 7,
    Compare_Op_Max = 8,
}
Rendering_Device_Logic_Operation :: enum int {
    Logic_Op_Clear = 0,
    Logic_Op_And = 1,
    Logic_Op_And_Reverse = 2,
    Logic_Op_Copy = 3,
    Logic_Op_And_Inverted = 4,
    Logic_Op_No_Op = 5,
    Logic_Op_Xor = 6,
    Logic_Op_Or = 7,
    Logic_Op_Nor = 8,
    Logic_Op_Equivalent = 9,
    Logic_Op_Invert = 10,
    Logic_Op_Or_Reverse = 11,
    Logic_Op_Copy_Inverted = 12,
    Logic_Op_Or_Inverted = 13,
    Logic_Op_Nand = 14,
    Logic_Op_Set = 15,
    Logic_Op_Max = 16,
}
Rendering_Device_Blend_Factor :: enum int {
    Blend_Factor_Zero = 0,
    Blend_Factor_One = 1,
    Blend_Factor_Src_Color = 2,
    Blend_Factor_One_Minus_Src_Color = 3,
    Blend_Factor_Dst_Color = 4,
    Blend_Factor_One_Minus_Dst_Color = 5,
    Blend_Factor_Src_Alpha = 6,
    Blend_Factor_One_Minus_Src_Alpha = 7,
    Blend_Factor_Dst_Alpha = 8,
    Blend_Factor_One_Minus_Dst_Alpha = 9,
    Blend_Factor_Constant_Color = 10,
    Blend_Factor_One_Minus_Constant_Color = 11,
    Blend_Factor_Constant_Alpha = 12,
    Blend_Factor_One_Minus_Constant_Alpha = 13,
    Blend_Factor_Src_Alpha_Saturate = 14,
    Blend_Factor_Src1_Color = 15,
    Blend_Factor_One_Minus_Src1_Color = 16,
    Blend_Factor_Src1_Alpha = 17,
    Blend_Factor_One_Minus_Src1_Alpha = 18,
    Blend_Factor_Max = 19,
}
Rendering_Device_Blend_Operation :: enum int {
    Blend_Op_Add = 0,
    Blend_Op_Subtract = 1,
    Blend_Op_Reverse_Subtract = 2,
    Blend_Op_Minimum = 3,
    Blend_Op_Maximum = 4,
    Blend_Op_Max = 5,
}
Rendering_Device_Initial_Action :: enum int {
    Initial_Action_Load = 0,
    Initial_Action_Clear = 1,
    Initial_Action_Discard = 2,
    Initial_Action_Max = 3,
    Initial_Action_Clear_Region = 1,
    Initial_Action_Clear_Region_Continue = 1,
    Initial_Action_Keep = 0,
    Initial_Action_Drop = 2,
    Initial_Action_Continue = 0,
}
Rendering_Device_Final_Action :: enum int {
    Final_Action_Store = 0,
    Final_Action_Discard = 1,
    Final_Action_Max = 2,
    Final_Action_Read = 0,
    Final_Action_Continue = 0,
}
Rendering_Device_Shader_Stage :: enum int {
    Shader_Stage_Vertex = 0,
    Shader_Stage_Fragment = 1,
    Shader_Stage_Tesselation_Control = 2,
    Shader_Stage_Tesselation_Evaluation = 3,
    Shader_Stage_Compute = 4,
    Shader_Stage_Max = 5,
    Shader_Stage_Vertex_Bit = 1,
    Shader_Stage_Fragment_Bit = 2,
    Shader_Stage_Tesselation_Control_Bit = 4,
    Shader_Stage_Tesselation_Evaluation_Bit = 8,
    Shader_Stage_Compute_Bit = 16,
}
Rendering_Device_Shader_Language :: enum int {
    Shader_Language_Glsl = 0,
    Shader_Language_Hlsl = 1,
}
Rendering_Device_Pipeline_Specialization_Constant_Type :: enum int {
    Pipeline_Specialization_Constant_Type_Bool = 0,
    Pipeline_Specialization_Constant_Type_Int = 1,
    Pipeline_Specialization_Constant_Type_Float = 2,
}
Rendering_Device_Features :: enum int {
    Supports_Metalfx_Spatial = 3,
    Supports_Metalfx_Temporal = 4,
    Supports_Buffer_Device_Address = 6,
    Supports_Image_Atomic_32_Bit = 7,
}
Rendering_Device_Limit :: enum int {
    Limit_Max_Bound_Uniform_Sets = 0,
    Limit_Max_Framebuffer_Color_Attachments = 1,
    Limit_Max_Textures_Per_Uniform_Set = 2,
    Limit_Max_Samplers_Per_Uniform_Set = 3,
    Limit_Max_Storage_Buffers_Per_Uniform_Set = 4,
    Limit_Max_Storage_Images_Per_Uniform_Set = 5,
    Limit_Max_Uniform_Buffers_Per_Uniform_Set = 6,
    Limit_Max_Draw_Indexed_Index = 7,
    Limit_Max_Framebuffer_Height = 8,
    Limit_Max_Framebuffer_Width = 9,
    Limit_Max_Texture_Array_Layers = 10,
    Limit_Max_Texture_Size_1d = 11,
    Limit_Max_Texture_Size_2d = 12,
    Limit_Max_Texture_Size_3d = 13,
    Limit_Max_Texture_Size_Cube = 14,
    Limit_Max_Textures_Per_Shader_Stage = 15,
    Limit_Max_Samplers_Per_Shader_Stage = 16,
    Limit_Max_Storage_Buffers_Per_Shader_Stage = 17,
    Limit_Max_Storage_Images_Per_Shader_Stage = 18,
    Limit_Max_Uniform_Buffers_Per_Shader_Stage = 19,
    Limit_Max_Push_Constant_Size = 20,
    Limit_Max_Uniform_Buffer_Size = 21,
    Limit_Max_Vertex_Input_Attribute_Offset = 22,
    Limit_Max_Vertex_Input_Attributes = 23,
    Limit_Max_Vertex_Input_Bindings = 24,
    Limit_Max_Vertex_Input_Binding_Stride = 25,
    Limit_Min_Uniform_Buffer_Offset_Alignment = 26,
    Limit_Max_Compute_Shared_Memory_Size = 27,
    Limit_Max_Compute_Workgroup_Count_X = 28,
    Limit_Max_Compute_Workgroup_Count_Y = 29,
    Limit_Max_Compute_Workgroup_Count_Z = 30,
    Limit_Max_Compute_Workgroup_Invocations = 31,
    Limit_Max_Compute_Workgroup_Size_X = 32,
    Limit_Max_Compute_Workgroup_Size_Y = 33,
    Limit_Max_Compute_Workgroup_Size_Z = 34,
    Limit_Max_Viewport_Dimensions_X = 35,
    Limit_Max_Viewport_Dimensions_Y = 36,
    Limit_Metalfx_Temporal_Scaler_Min_Scale = 46,
    Limit_Metalfx_Temporal_Scaler_Max_Scale = 47,
}
Rendering_Device_Memory_Type :: enum int {
    Memory_Textures = 0,
    Memory_Buffers = 1,
    Memory_Total = 2,
}
Rendering_Device_Breadcrumb_Marker :: enum int {
    None = 0,
    Reflection_Probes = 65536,
    Sky_Pass = 131072,
    Lightmapper_Pass = 196608,
    Shadow_Pass_Directional = 262144,
    Shadow_Pass_Cube = 327680,
    Opaque_Pass = 393216,
    Alpha_Pass = 458752,
    Transparent_Pass = 524288,
    Post_Processing_Pass = 589824,
    Blit_Pass = 655360,
    Ui_Pass = 720896,
    Debug_Pass = 786432,
}

Rendering_Device_Barrier_Mask :: enum i64 {
    Barrier_Mask_Vertex = 1,
    Barrier_Mask_Fragment = 8,
    Barrier_Mask_Compute = 2,
    Barrier_Mask_Transfer = 4,
    Barrier_Mask_Raster = 9,
    Barrier_Mask_All_Barriers = 32767,
    Barrier_Mask_No_Barrier = 32768,
}
Rendering_Device_Texture_Usage_Bits :: enum i64 {
    Texture_Usage_Sampling_Bit = 1,
    Texture_Usage_Color_Attachment_Bit = 2,
    Texture_Usage_Depth_Stencil_Attachment_Bit = 4,
    Texture_Usage_Depth_Resolve_Attachment_Bit = 4096,
    Texture_Usage_Storage_Bit = 8,
    Texture_Usage_Storage_Atomic_Bit = 16,
    Texture_Usage_Cpu_Read_Bit = 32,
    Texture_Usage_Can_Update_Bit = 64,
    Texture_Usage_Can_Copy_From_Bit = 128,
    Texture_Usage_Can_Copy_To_Bit = 256,
    Texture_Usage_Input_Attachment_Bit = 512,
}
Rendering_Device_Storage_Buffer_Usage :: enum i64 {
    Storage_Buffer_Usage_Dispatch_Indirect = 1,
}
Rendering_Device_Buffer_Creation_Bits :: enum i64 {
    Buffer_Creation_Device_Address_Bit = 1,
    Buffer_Creation_As_Storage_Bit = 2,
}
Rendering_Device_Pipeline_Dynamic_State_Flags :: enum i64 {
    Dynamic_State_Line_Width = 1,
    Dynamic_State_Depth_Bias = 2,
    Dynamic_State_Blend_Constants = 4,
    Dynamic_State_Depth_Bounds = 8,
    Dynamic_State_Stencil_Compare_Mask = 16,
    Dynamic_State_Stencil_Write_Mask = 32,
    Dynamic_State_Stencil_Reference = 64,
}
Rendering_Device_Draw_Flags :: enum i64 {
    Draw_Default_All = 0,
    Draw_Clear_Color_0 = 1,
    Draw_Clear_Color_1 = 2,
    Draw_Clear_Color_2 = 4,
    Draw_Clear_Color_3 = 8,
    Draw_Clear_Color_4 = 16,
    Draw_Clear_Color_5 = 32,
    Draw_Clear_Color_6 = 64,
    Draw_Clear_Color_7 = 128,
    Draw_Clear_Color_Mask = 255,
    Draw_Clear_Color_All = 255,
    Draw_Ignore_Color_0 = 256,
    Draw_Ignore_Color_1 = 512,
    Draw_Ignore_Color_2 = 1024,
    Draw_Ignore_Color_3 = 2048,
    Draw_Ignore_Color_4 = 4096,
    Draw_Ignore_Color_5 = 8192,
    Draw_Ignore_Color_6 = 16384,
    Draw_Ignore_Color_7 = 32768,
    Draw_Ignore_Color_Mask = 65280,
    Draw_Ignore_Color_All = 65280,
    Draw_Clear_Depth = 65536,
    Draw_Ignore_Depth = 131072,
    Draw_Clear_Stencil = 262144,
    Draw_Ignore_Stencil = 524288,
    Draw_Clear_All = 327935,
    Draw_Ignore_All = 720640,
}


rendering_device_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rendering_device_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rendering_device :: proc "contextless" () -> Rendering_Device {
    return __bindgen_gde.classdb_construct_object(rendering_device_name_ref())
}

// methods
//
// Method binds are resolved LAZILY on first call (the `@(static) __ptr` guard),
// NOT eagerly in `_init`. Many engine classes (Node, Control, the *Server
// singletons, ...) are only registered with ClassDB at later initialization
// levels (Servers/Scene), while `godot.init()` runs at the extension entry
// (Core level). Eagerly fetching every bind there returned null for ~91% of
// methods (a 16k-line `mb is null` flood). Resolving on first call defers the
// fetch to a point where the owning class is registered, mirroring how the
// builtin/variant methods already work. A genuinely unresolvable bind stays
// nil and the following ptrcall surfaces it at the call site.
//
// VARARG methods (`is_vararg` in extension_api.json) cannot use ptrcall — Godot
// aborts with "ptrcall can't be used with vararg methods". They instead go
// through `object_method_bind_call`: the fixed declared args are marshalled to
// Variants, the variadic `extra: ..Variant` are appended, and the returned
// Variant is converted to the declared return type (Variant passed through,
// `Error`/ints via variant_to_int, void ignored).

rendering_device_texture_create :: proc "contextless" (
    self: Rendering_Device,
    format_: Rd_Texture_Format,
    view_: Rd_Texture_View,
    data_: Typed_Array(Packed_Byte_Array),
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3709173589)
    }
    self := self
    format_ := format_
    view_ := view_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &format_,
        &view_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_create_shared :: proc "contextless" (
    self: Rendering_Device,
    view_: Rd_Texture_View,
    with_texture_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_create_shared", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3178156134)
    }
    self := self
    view_ := view_
    with_texture_ := with_texture_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &with_texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_create_shared_from_slice :: proc "contextless" (
    self: Rendering_Device,
    view_: Rd_Texture_View,
    with_texture_: Rid,
    layer_: Int,
    mipmap_: Int,
    mipmaps_: Int,
    slice_type_: Rendering_Device_Texture_Slice_Type,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_create_shared_from_slice", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1808971279)
    }
    self := self
    view_ := view_
    with_texture_ := with_texture_
    layer_ := layer_
    mipmap_ := mipmap_
    mipmaps_ := mipmaps_
    slice_type_ := slice_type_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &with_texture_,
        &layer_,
        &mipmap_,
        &mipmaps_,
        &slice_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_create_from_extension :: proc "contextless" (
    self: Rendering_Device,
    type_: Rendering_Device_Texture_Type,
    format_: Rendering_Device_Data_Format,
    samples_: Rendering_Device_Texture_Samples,
    usage_flags_: Rendering_Device_Texture_Usage_Bits,
    image_: Int,
    width_: Int,
    height_: Int,
    depth_: Int,
    layers_: Int,
    mipmaps_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_create_from_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3732868568)
    }
    self := self
    type_ := type_
    format_ := format_
    samples_ := samples_
    usage_flags_ := usage_flags_
    image_ := image_
    width_ := width_
    height_ := height_
    depth_ := depth_
    layers_ := layers_
    mipmaps_ := mipmaps_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &format_,
        &samples_,
        &usage_flags_,
        &image_,
        &width_,
        &height_,
        &depth_,
        &layers_,
        &mipmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_update :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
    layer_: Int,
    data_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1349464008)
    }
    self := self
    texture_ := texture_
    layer_ := layer_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &layer_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_get_data :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
    layer_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_get_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1859412099)
    }
    self := self
    texture_ := texture_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_get_data_async :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
    layer_: Int,
    callback_: Callable,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_get_data_async", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 498832090)
    }
    self := self
    texture_ := texture_
    layer_ := layer_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &layer_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_is_format_supported_for_usage :: proc "contextless" (
    self: Rendering_Device,
    format_: Rendering_Device_Data_Format,
    usage_flags_: Rendering_Device_Texture_Usage_Bits,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_is_format_supported_for_usage", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2592520478)
    }
    self := self
    format_ := format_
    usage_flags_ := usage_flags_
    args := []__bindgen_gde.TypePtr {
        &format_,
        &usage_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_is_shared :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_is_shared", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_is_valid :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_set_discardable :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
    discardable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_set_discardable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    texture_ := texture_
    discardable_ := discardable_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &discardable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_texture_is_discardable :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_is_discardable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_copy :: proc "contextless" (
    self: Rendering_Device,
    from_texture_: Rid,
    to_texture_: Rid,
    from_pos_: Vector3,
    to_pos_: Vector3,
    size_: Vector3,
    src_mipmap_: Int,
    dst_mipmap_: Int,
    src_layer_: Int,
    dst_layer_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_copy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2859522160)
    }
    self := self
    from_texture_ := from_texture_
    to_texture_ := to_texture_
    from_pos_ := from_pos_
    to_pos_ := to_pos_
    size_ := size_
    src_mipmap_ := src_mipmap_
    dst_mipmap_ := dst_mipmap_
    src_layer_ := src_layer_
    dst_layer_ := dst_layer_
    args := []__bindgen_gde.TypePtr {
        &from_texture_,
        &to_texture_,
        &from_pos_,
        &to_pos_,
        &size_,
        &src_mipmap_,
        &dst_mipmap_,
        &src_layer_,
        &dst_layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_clear :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
    color_: Color,
    base_mipmap_: Int,
    mipmap_count_: Int,
    base_layer_: Int,
    layer_count_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3477703247)
    }
    self := self
    texture_ := texture_
    color_ := color_
    base_mipmap_ := base_mipmap_
    mipmap_count_ := mipmap_count_
    base_layer_ := base_layer_
    layer_count_ := layer_count_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &color_,
        &base_mipmap_,
        &mipmap_count_,
        &base_layer_,
        &layer_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_resolve_multisample :: proc "contextless" (
    self: Rendering_Device,
    from_texture_: Rid,
    to_texture_: Rid,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_resolve_multisample", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3181288260)
    }
    self := self
    from_texture_ := from_texture_
    to_texture_ := to_texture_
    args := []__bindgen_gde.TypePtr {
        &from_texture_,
        &to_texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_get_format :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
) -> (ret: Rd_Texture_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_get_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1374471690)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_get_native_handle :: proc "contextless" (
    self: Rendering_Device,
    texture_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_get_native_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_format_create :: proc "contextless" (
    self: Rendering_Device,
    attachments_: Typed_Array(Rd_Attachment_Format),
    view_count_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_format_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 697032759)
    }
    self := self
    attachments_ := attachments_
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &attachments_,
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_format_create_multipass :: proc "contextless" (
    self: Rendering_Device,
    attachments_: Typed_Array(Rd_Attachment_Format),
    passes_: Typed_Array(Rd_Framebuffer_Pass),
    view_count_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_format_create_multipass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2647479094)
    }
    self := self
    attachments_ := attachments_
    passes_ := passes_
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &attachments_,
        &passes_,
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_format_create_empty :: proc "contextless" (
    self: Rendering_Device,
    samples_: Rendering_Device_Texture_Samples,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_format_create_empty", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 555930169)
    }
    self := self
    samples_ := samples_
    args := []__bindgen_gde.TypePtr {
        &samples_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_format_get_texture_samples :: proc "contextless" (
    self: Rendering_Device,
    format_: Int,
    render_pass_: Int,
) -> (ret: Rendering_Device_Texture_Samples) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_format_get_texture_samples", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4223391010)
    }
    self := self
    format_ := format_
    render_pass_ := render_pass_
    args := []__bindgen_gde.TypePtr {
        &format_,
        &render_pass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_create :: proc "contextless" (
    self: Rendering_Device,
    textures_: Typed_Array(Rid),
    validate_with_format_: Int,
    view_count_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3284231055)
    }
    self := self
    textures_ := textures_
    validate_with_format_ := validate_with_format_
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &textures_,
        &validate_with_format_,
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_create_multipass :: proc "contextless" (
    self: Rendering_Device,
    textures_: Typed_Array(Rid),
    passes_: Typed_Array(Rd_Framebuffer_Pass),
    validate_with_format_: Int,
    view_count_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_create_multipass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1750306695)
    }
    self := self
    textures_ := textures_
    passes_ := passes_
    validate_with_format_ := validate_with_format_
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &textures_,
        &passes_,
        &validate_with_format_,
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_create_empty :: proc "contextless" (
    self: Rendering_Device,
    size_: Vector2i,
    samples_: Rendering_Device_Texture_Samples,
    validate_with_format_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_create_empty", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3058360618)
    }
    self := self
    size_ := size_
    samples_ := samples_
    validate_with_format_ := validate_with_format_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &samples_,
        &validate_with_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_get_format :: proc "contextless" (
    self: Rendering_Device,
    framebuffer_: Rid,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_get_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    framebuffer_ := framebuffer_
    args := []__bindgen_gde.TypePtr {
        &framebuffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_framebuffer_is_valid :: proc "contextless" (
    self: Rendering_Device,
    framebuffer_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("framebuffer_is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    framebuffer_ := framebuffer_
    args := []__bindgen_gde.TypePtr {
        &framebuffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_sampler_create :: proc "contextless" (
    self: Rendering_Device,
    state_: Rd_Sampler_State,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sampler_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2327892535)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_sampler_is_format_supported_for_filter :: proc "contextless" (
    self: Rendering_Device,
    format_: Rendering_Device_Data_Format,
    sampler_filter_: Rendering_Device_Sampler_Filter,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sampler_is_format_supported_for_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2247922238)
    }
    self := self
    format_ := format_
    sampler_filter_ := sampler_filter_
    args := []__bindgen_gde.TypePtr {
        &format_,
        &sampler_filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_vertex_buffer_create :: proc "contextless" (
    self: Rendering_Device,
    size_bytes_: Int,
    data_: Packed_Byte_Array,
    creation_bits_: Rendering_Device_Buffer_Creation_Bits,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("vertex_buffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2089548973)
    }
    self := self
    size_bytes_ := size_bytes_
    data_ := data_
    creation_bits_ := creation_bits_
    args := []__bindgen_gde.TypePtr {
        &size_bytes_,
        &data_,
        &creation_bits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_vertex_format_create :: proc "contextless" (
    self: Rendering_Device,
    vertex_descriptions_: Typed_Array(Rd_Vertex_Attribute),
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("vertex_format_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1242678479)
    }
    self := self
    vertex_descriptions_ := vertex_descriptions_
    args := []__bindgen_gde.TypePtr {
        &vertex_descriptions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_vertex_array_create :: proc "contextless" (
    self: Rendering_Device,
    vertex_count_: Int,
    vertex_format_: Int,
    src_buffers_: Typed_Array(Rid),
    offsets_: Packed_Int64_Array,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("vertex_array_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3799816279)
    }
    self := self
    vertex_count_ := vertex_count_
    vertex_format_ := vertex_format_
    src_buffers_ := src_buffers_
    offsets_ := offsets_
    args := []__bindgen_gde.TypePtr {
        &vertex_count_,
        &vertex_format_,
        &src_buffers_,
        &offsets_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_index_buffer_create :: proc "contextless" (
    self: Rendering_Device,
    size_indices_: Int,
    format_: Rendering_Device_Index_Buffer_Format,
    data_: Packed_Byte_Array,
    use_restart_indices_: Bool,
    creation_bits_: Rendering_Device_Buffer_Creation_Bits,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("index_buffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2368684885)
    }
    self := self
    size_indices_ := size_indices_
    format_ := format_
    data_ := data_
    use_restart_indices_ := use_restart_indices_
    creation_bits_ := creation_bits_
    args := []__bindgen_gde.TypePtr {
        &size_indices_,
        &format_,
        &data_,
        &use_restart_indices_,
        &creation_bits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_index_array_create :: proc "contextless" (
    self: Rendering_Device,
    index_buffer_: Rid,
    index_offset_: Int,
    index_count_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("index_array_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2256026069)
    }
    self := self
    index_buffer_ := index_buffer_
    index_offset_ := index_offset_
    index_count_ := index_count_
    args := []__bindgen_gde.TypePtr {
        &index_buffer_,
        &index_offset_,
        &index_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_compile_spirv_from_source :: proc "contextless" (
    self: Rendering_Device,
    shader_source_: Rd_Shader_Source,
    allow_cache_: Bool,
) -> (ret: Rd_Shader_Spirv) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_compile_spirv_from_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1178973306)
    }
    self := self
    shader_source_ := shader_source_
    allow_cache_ := allow_cache_
    args := []__bindgen_gde.TypePtr {
        &shader_source_,
        &allow_cache_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_compile_binary_from_spirv :: proc "contextless" (
    self: Rendering_Device,
    spirv_data_: Rd_Shader_Spirv,
    name_: String,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_compile_binary_from_spirv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 134910450)
    }
    self := self
    spirv_data_ := spirv_data_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &spirv_data_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_create_from_spirv :: proc "contextless" (
    self: Rendering_Device,
    spirv_data_: Rd_Shader_Spirv,
    name_: String,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_create_from_spirv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 342949005)
    }
    self := self
    spirv_data_ := spirv_data_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &spirv_data_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_create_from_bytecode :: proc "contextless" (
    self: Rendering_Device,
    binary_data_: Packed_Byte_Array,
    placeholder_rid_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_create_from_bytecode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1687031350)
    }
    self := self
    binary_data_ := binary_data_
    placeholder_rid_ := placeholder_rid_
    args := []__bindgen_gde.TypePtr {
        &binary_data_,
        &placeholder_rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_create_placeholder :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_create_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_shader_get_vertex_input_attribute_mask :: proc "contextless" (
    self: Rendering_Device,
    shader_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shader_get_vertex_input_attribute_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    shader_ := shader_
    args := []__bindgen_gde.TypePtr {
        &shader_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_uniform_buffer_create :: proc "contextless" (
    self: Rendering_Device,
    size_bytes_: Int,
    data_: Packed_Byte_Array,
    creation_bits_: Rendering_Device_Buffer_Creation_Bits,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uniform_buffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2089548973)
    }
    self := self
    size_bytes_ := size_bytes_
    data_ := data_
    creation_bits_ := creation_bits_
    args := []__bindgen_gde.TypePtr {
        &size_bytes_,
        &data_,
        &creation_bits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_storage_buffer_create :: proc "contextless" (
    self: Rendering_Device,
    size_bytes_: Int,
    data_: Packed_Byte_Array,
    usage_: Rendering_Device_Storage_Buffer_Usage,
    creation_bits_: Rendering_Device_Buffer_Creation_Bits,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("storage_buffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1609052553)
    }
    self := self
    size_bytes_ := size_bytes_
    data_ := data_
    usage_ := usage_
    creation_bits_ := creation_bits_
    args := []__bindgen_gde.TypePtr {
        &size_bytes_,
        &data_,
        &usage_,
        &creation_bits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_texture_buffer_create :: proc "contextless" (
    self: Rendering_Device,
    size_bytes_: Int,
    format_: Rendering_Device_Data_Format,
    data_: Packed_Byte_Array,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("texture_buffer_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1470338698)
    }
    self := self
    size_bytes_ := size_bytes_
    format_ := format_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &size_bytes_,
        &format_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_uniform_set_create :: proc "contextless" (
    self: Rendering_Device,
    uniforms_: Typed_Array(Rd_Uniform),
    shader_: Rid,
    shader_set_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uniform_set_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2280795797)
    }
    self := self
    uniforms_ := uniforms_
    shader_ := shader_
    shader_set_ := shader_set_
    args := []__bindgen_gde.TypePtr {
        &uniforms_,
        &shader_,
        &shader_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_uniform_set_is_valid :: proc "contextless" (
    self: Rendering_Device,
    uniform_set_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uniform_set_is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    uniform_set_ := uniform_set_
    args := []__bindgen_gde.TypePtr {
        &uniform_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_copy :: proc "contextless" (
    self: Rendering_Device,
    src_buffer_: Rid,
    dst_buffer_: Rid,
    src_offset_: Int,
    dst_offset_: Int,
    size_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_copy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 864257779)
    }
    self := self
    src_buffer_ := src_buffer_
    dst_buffer_ := dst_buffer_
    src_offset_ := src_offset_
    dst_offset_ := dst_offset_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &src_buffer_,
        &dst_buffer_,
        &src_offset_,
        &dst_offset_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_update :: proc "contextless" (
    self: Rendering_Device,
    buffer_: Rid,
    offset_: Int,
    size_bytes_: Int,
    data_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3454956949)
    }
    self := self
    buffer_ := buffer_
    offset_ := offset_
    size_bytes_ := size_bytes_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &offset_,
        &size_bytes_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_clear :: proc "contextless" (
    self: Rendering_Device,
    buffer_: Rid,
    offset_: Int,
    size_bytes_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2452320800)
    }
    self := self
    buffer_ := buffer_
    offset_ := offset_
    size_bytes_ := size_bytes_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &offset_,
        &size_bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_get_data :: proc "contextless" (
    self: Rendering_Device,
    buffer_: Rid,
    offset_bytes_: Int,
    size_bytes_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_get_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3101830688)
    }
    self := self
    buffer_ := buffer_
    offset_bytes_ := offset_bytes_
    size_bytes_ := size_bytes_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &offset_bytes_,
        &size_bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_get_data_async :: proc "contextless" (
    self: Rendering_Device,
    buffer_: Rid,
    callback_: Callable,
    offset_bytes_: Int,
    size_bytes_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_get_data_async", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2370287848)
    }
    self := self
    buffer_ := buffer_
    callback_ := callback_
    offset_bytes_ := offset_bytes_
    size_bytes_ := size_bytes_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &callback_,
        &offset_bytes_,
        &size_bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_buffer_get_device_address :: proc "contextless" (
    self: Rendering_Device,
    buffer_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("buffer_get_device_address", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_render_pipeline_create :: proc "contextless" (
    self: Rendering_Device,
    shader_: Rid,
    framebuffer_format_: Int,
    vertex_format_: Int,
    primitive_: Rendering_Device_Render_Primitive,
    rasterization_state_: Rd_Pipeline_Rasterization_State,
    multisample_state_: Rd_Pipeline_Multisample_State,
    stencil_state_: Rd_Pipeline_Depth_Stencil_State,
    color_blend_state_: Rd_Pipeline_Color_Blend_State,
    dynamic_state_flags_: Rendering_Device_Pipeline_Dynamic_State_Flags,
    for_render_pass_: Int,
    specialization_constants_: Typed_Array(Rd_Pipeline_Specialization_Constant),
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_pipeline_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2385451958)
    }
    self := self
    shader_ := shader_
    framebuffer_format_ := framebuffer_format_
    vertex_format_ := vertex_format_
    primitive_ := primitive_
    rasterization_state_ := rasterization_state_
    multisample_state_ := multisample_state_
    stencil_state_ := stencil_state_
    color_blend_state_ := color_blend_state_
    dynamic_state_flags_ := dynamic_state_flags_
    for_render_pass_ := for_render_pass_
    specialization_constants_ := specialization_constants_
    args := []__bindgen_gde.TypePtr {
        &shader_,
        &framebuffer_format_,
        &vertex_format_,
        &primitive_,
        &rasterization_state_,
        &multisample_state_,
        &stencil_state_,
        &color_blend_state_,
        &dynamic_state_flags_,
        &for_render_pass_,
        &specialization_constants_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_render_pipeline_is_valid :: proc "contextless" (
    self: Rendering_Device,
    render_pipeline_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_pipeline_is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    render_pipeline_ := render_pipeline_
    args := []__bindgen_gde.TypePtr {
        &render_pipeline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_compute_pipeline_create :: proc "contextless" (
    self: Rendering_Device,
    shader_: Rid,
    specialization_constants_: Typed_Array(Rd_Pipeline_Specialization_Constant),
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_pipeline_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1448838280)
    }
    self := self
    shader_ := shader_
    specialization_constants_ := specialization_constants_
    args := []__bindgen_gde.TypePtr {
        &shader_,
        &specialization_constants_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_compute_pipeline_is_valid :: proc "contextless" (
    self: Rendering_Device,
    compute_pipeline_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_pipeline_is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    compute_pipeline_ := compute_pipeline_
    args := []__bindgen_gde.TypePtr {
        &compute_pipeline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_screen_get_width :: proc "contextless" (
    self: Rendering_Device,
    screen_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_screen_get_height :: proc "contextless" (
    self: Rendering_Device,
    screen_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_screen_get_framebuffer_format :: proc "contextless" (
    self: Rendering_Device,
    screen_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_framebuffer_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_begin_for_screen :: proc "contextless" (
    self: Rendering_Device,
    screen_: Int,
    clear_color_: Color,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_begin_for_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3988079995)
    }
    self := self
    screen_ := screen_
    clear_color_ := clear_color_
    args := []__bindgen_gde.TypePtr {
        &screen_,
        &clear_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_begin :: proc "contextless" (
    self: Rendering_Device,
    framebuffer_: Rid,
    draw_flags_: Rendering_Device_Draw_Flags,
    clear_color_values_: Packed_Color_Array,
    clear_depth_value_: f64,
    clear_stencil_value_: Int,
    region_: Rect2,
    breadcrumb_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1317926357)
    }
    self := self
    framebuffer_ := framebuffer_
    draw_flags_ := draw_flags_
    clear_color_values_ := clear_color_values_
    clear_depth_value_ := clear_depth_value_
    clear_stencil_value_ := clear_stencil_value_
    region_ := region_
    breadcrumb_ := breadcrumb_
    args := []__bindgen_gde.TypePtr {
        &framebuffer_,
        &draw_flags_,
        &clear_color_values_,
        &clear_depth_value_,
        &clear_stencil_value_,
        &region_,
        &breadcrumb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_begin_split :: proc "contextless" (
    self: Rendering_Device,
    framebuffer_: Rid,
    splits_: Int,
    initial_color_action_: Rendering_Device_Initial_Action,
    final_color_action_: Rendering_Device_Final_Action,
    initial_depth_action_: Rendering_Device_Initial_Action,
    final_depth_action_: Rendering_Device_Final_Action,
    clear_color_values_: Packed_Color_Array,
    clear_depth_: f64,
    clear_stencil_: Int,
    region_: Rect2,
    storage_textures_: Typed_Array(Rid),
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_begin_split", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2406300660)
    }
    self := self
    framebuffer_ := framebuffer_
    splits_ := splits_
    initial_color_action_ := initial_color_action_
    final_color_action_ := final_color_action_
    initial_depth_action_ := initial_depth_action_
    final_depth_action_ := final_depth_action_
    clear_color_values_ := clear_color_values_
    clear_depth_ := clear_depth_
    clear_stencil_ := clear_stencil_
    region_ := region_
    storage_textures_ := storage_textures_
    args := []__bindgen_gde.TypePtr {
        &framebuffer_,
        &splits_,
        &initial_color_action_,
        &final_color_action_,
        &initial_depth_action_,
        &final_depth_action_,
        &clear_color_values_,
        &clear_depth_,
        &clear_stencil_,
        &region_,
        &storage_textures_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_set_blend_constants :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_set_blend_constants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    draw_list_ := draw_list_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_bind_render_pipeline :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    render_pipeline_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_bind_render_pipeline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    draw_list_ := draw_list_
    render_pipeline_ := render_pipeline_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &render_pipeline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_bind_uniform_set :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    uniform_set_: Rid,
    set_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_bind_uniform_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 749655778)
    }
    self := self
    draw_list_ := draw_list_
    uniform_set_ := uniform_set_
    set_index_ := set_index_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &uniform_set_,
        &set_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_bind_vertex_array :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    vertex_array_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_bind_vertex_array", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    draw_list_ := draw_list_
    vertex_array_ := vertex_array_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &vertex_array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_bind_vertex_buffers_format :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    vertex_format_: Int,
    vertex_count_: Int,
    vertex_buffers_: Typed_Array(Rid),
    offsets_: Packed_Int64_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_bind_vertex_buffers_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2008628980)
    }
    self := self
    draw_list_ := draw_list_
    vertex_format_ := vertex_format_
    vertex_count_ := vertex_count_
    vertex_buffers_ := vertex_buffers_
    offsets_ := offsets_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &vertex_format_,
        &vertex_count_,
        &vertex_buffers_,
        &offsets_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_bind_index_array :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    index_array_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_bind_index_array", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    draw_list_ := draw_list_
    index_array_ := index_array_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &index_array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_set_push_constant :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    buffer_: Packed_Byte_Array,
    size_bytes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_set_push_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2772371345)
    }
    self := self
    draw_list_ := draw_list_
    buffer_ := buffer_
    size_bytes_ := size_bytes_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &buffer_,
        &size_bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_draw :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    use_indices_: Bool,
    instances_: Int,
    procedural_vertex_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4230067973)
    }
    self := self
    draw_list_ := draw_list_
    use_indices_ := use_indices_
    instances_ := instances_
    procedural_vertex_count_ := procedural_vertex_count_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &use_indices_,
        &instances_,
        &procedural_vertex_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_draw_indirect :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    use_indices_: Bool,
    buffer_: Rid,
    offset_: Int,
    draw_count_: Int,
    stride_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_draw_indirect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1092133571)
    }
    self := self
    draw_list_ := draw_list_
    use_indices_ := use_indices_
    buffer_ := buffer_
    offset_ := offset_
    draw_count_ := draw_count_
    stride_ := stride_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &use_indices_,
        &buffer_,
        &offset_,
        &draw_count_,
        &stride_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_enable_scissor :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_enable_scissor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 244650101)
    }
    self := self
    draw_list_ := draw_list_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_disable_scissor :: proc "contextless" (
    self: Rendering_Device,
    draw_list_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_disable_scissor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    draw_list_ := draw_list_
    args := []__bindgen_gde.TypePtr {
        &draw_list_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_list_switch_to_next_pass :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_switch_to_next_pass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_switch_to_next_pass_split :: proc "contextless" (
    self: Rendering_Device,
    splits_: Int,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_switch_to_next_pass_split", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2865087369)
    }
    self := self
    splits_ := splits_
    args := []__bindgen_gde.TypePtr {
        &splits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_draw_list_end :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_list_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_begin :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_compute_list_bind_compute_pipeline :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
    compute_pipeline_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_bind_compute_pipeline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    compute_list_ := compute_list_
    compute_pipeline_ := compute_pipeline_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
        &compute_pipeline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_set_push_constant :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
    buffer_: Packed_Byte_Array,
    size_bytes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_set_push_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2772371345)
    }
    self := self
    compute_list_ := compute_list_
    buffer_ := buffer_
    size_bytes_ := size_bytes_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
        &buffer_,
        &size_bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_bind_uniform_set :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
    uniform_set_: Rid,
    set_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_bind_uniform_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 749655778)
    }
    self := self
    compute_list_ := compute_list_
    uniform_set_ := uniform_set_
    set_index_ := set_index_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
        &uniform_set_,
        &set_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_dispatch :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
    x_groups_: Int,
    y_groups_: Int,
    z_groups_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_dispatch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4275841770)
    }
    self := self
    compute_list_ := compute_list_
    x_groups_ := x_groups_
    y_groups_ := y_groups_
    z_groups_ := z_groups_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
        &x_groups_,
        &y_groups_,
        &z_groups_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_dispatch_indirect :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
    buffer_: Rid,
    offset_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_dispatch_indirect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 749655778)
    }
    self := self
    compute_list_ := compute_list_
    buffer_ := buffer_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
        &buffer_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_add_barrier :: proc "contextless" (
    self: Rendering_Device,
    compute_list_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_add_barrier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    compute_list_ := compute_list_
    args := []__bindgen_gde.TypePtr {
        &compute_list_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_compute_list_end :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_list_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_free_rid :: proc "contextless" (
    self: Rendering_Device,
    rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_capture_timestamp :: proc "contextless" (
    self: Rendering_Device,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("capture_timestamp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_get_captured_timestamps_count :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_captured_timestamps_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_captured_timestamps_frame :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_captured_timestamps_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_captured_timestamp_gpu_time :: proc "contextless" (
    self: Rendering_Device,
    index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_captured_timestamp_gpu_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_captured_timestamp_cpu_time :: proc "contextless" (
    self: Rendering_Device,
    index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_captured_timestamp_cpu_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_captured_timestamp_name :: proc "contextless" (
    self: Rendering_Device,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_captured_timestamp_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_has_feature :: proc "contextless" (
    self: Rendering_Device,
    feature_: Rendering_Device_Features,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1772728326)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_limit_get :: proc "contextless" (
    self: Rendering_Device,
    limit_: Rendering_Device_Limit,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("limit_get", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1559202131)
    }
    self := self
    limit_ := limit_
    args := []__bindgen_gde.TypePtr {
        &limit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_frame_delay :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frame_delay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_submit :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("submit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_sync :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_barrier :: proc "contextless" (
    self: Rendering_Device,
    from_: Rendering_Device_Barrier_Mask,
    to_: Rendering_Device_Barrier_Mask,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("barrier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3718155691)
    }
    self := self
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_full_barrier :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("full_barrier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_create_local_device :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: Rendering_Device) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_local_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2846302423)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_set_resource_name :: proc "contextless" (
    self: Rendering_Device,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_resource_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_command_begin_label :: proc "contextless" (
    self: Rendering_Device,
    name_: String,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_command_begin_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1636512886)
    }
    self := self
    name_ := name_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_command_insert_label :: proc "contextless" (
    self: Rendering_Device,
    name_: String,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_command_insert_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1636512886)
    }
    self := self
    name_ := name_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_draw_command_end_label :: proc "contextless" (
    self: Rendering_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_command_end_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rendering_device_get_device_vendor_name :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_vendor_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_name :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_pipeline_cache_uuid :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_pipeline_cache_uuid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_memory_usage :: proc "contextless" (
    self: Rendering_Device,
    type_: Rendering_Device_Memory_Type,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_memory_usage", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 251690689)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_resource :: proc "contextless" (
    self: Rendering_Device,
    resource_: Rendering_Device_Driver_Resource,
    rid_: Rid,
    index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_resource", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501815484)
    }
    self := self
    resource_ := resource_
    rid_ := rid_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &rid_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_perf_report :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_perf_report", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_and_device_memory_report :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_and_device_memory_report", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_tracked_object_name :: proc "contextless" (
    self: Rendering_Device,
    type_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracked_object_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    type_index_ := type_index_
    args := []__bindgen_gde.TypePtr {
        &type_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_tracked_object_type_count :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracked_object_type_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_total_memory :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_total_memory", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_allocation_count :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_allocation_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_memory_by_object_type :: proc "contextless" (
    self: Rendering_Device,
    type_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_memory_by_object_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_driver_allocs_by_object_type :: proc "contextless" (
    self: Rendering_Device,
    type_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_allocs_by_object_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_total_memory :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_total_memory", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_allocation_count :: proc "contextless" (
    self: Rendering_Device,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_allocation_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_memory_by_object_type :: proc "contextless" (
    self: Rendering_Device,
    type_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_memory_by_object_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rendering_device_get_device_allocs_by_object_type :: proc "contextless" (
    self: Rendering_Device,
    type_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_allocs_by_object_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
rendering_device_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RenderingDevice", true)
}

@(private = "file")
__class_name: String_Name