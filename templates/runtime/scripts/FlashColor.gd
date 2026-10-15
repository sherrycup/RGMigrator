extends RefCounted
## 0022 Color arithmetic, using Godot's normalized channels and source clamps.
static func rgba(color: Color) -> Array: return [color.r*255,color.g*255,color.b*255,color.a*255]
static func rgb(color: Color) -> Array: return [color.r*255,color.g*255,color.b*255]
static func add(first: Color,second: Variant) -> Color: return (first+second).clamp() if second is Color else first
static func subtract(first: Color,second: Variant) -> Color: return (first-second).clamp() if second is Color else first
static func multiply(color: Color,value: Variant) -> Color: return (color*float(value)).clamp() if value is int or value is float else color
static func divide(color: Color,value: Variant) -> Variant: return null if value==0 else multiply(color,1.0/float(value)) if value is int or value is float else color
