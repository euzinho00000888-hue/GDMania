class_name GameColors
extends RefCounted

const LANES := [Color("c24b99"), Color("00e5ff"), Color("12fa05"), Color("f9393f")]

static func lane(i: int) -> Color:
	return LANES[i]
