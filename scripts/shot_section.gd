extends Resource
class_name ShotSection
## One section of a height profile's Shots Away (height_profile.gd): a ring
## round the thing you stand on, out to `radius_m` from its middle (the last
## section reaches as far as a bullet goes: its radius doesn't count). Firing
## from up there at cover as high as where you stand or lower, met in this section,
## this share of the shots gets through it, by the cover's height class
## (never less than gets through anyway). 100% and every shot gets past it.

## How far out from the middle this section reaches.
@export_range(0.0, 60.0, 0.5, "suffix:m") var radius_m := 5.0
## Of the shots meeting height class 1 cover in this section (sandbags, the
## radio station), this share gets through.
@export_range(0, 100, 1, "suffix:%") var class_1_pass_through := 0
## The same for height class 2 cover (crates).
@export_range(0, 100, 1, "suffix:%") var class_2_pass_through := 0
## The same for height class 3 cover (a watch tower's steel, a helicopter).
@export_range(0, 100, 1, "suffix:%") var class_3_pass_through := 0


## The share (0..1) of shots that get through cover of height class `cls` here.
func pass_for(cls: int) -> float:
	return [class_1_pass_through, class_2_pass_through, class_3_pass_through][clampi(cls, 1, 3) - 1] / 100.0
