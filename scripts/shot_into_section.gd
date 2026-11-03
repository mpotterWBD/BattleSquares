extends Resource
class_name ShotIntoSection
## One section of a height profile's Shots Into (height_profile.gd; Mike,
## 2026-11-02): a ring round the part, out to `radius_m` from its middle,
## measured by how far the SHOOTER is from it (the last section reaches as far
## as a bullet goes: its radius doesn't count). Shot at from in here, someone
## on the part is covered by its Pass Through for this distance (in place of
## the profile's own: from close up it's easier to hit them than from far),
## and Seen says whether low cover gets ignored when someone in here looks at
## them (ticked: sandbags and crates don't hide them; unticked: cover works as
## on the ground; it never makes them invisible). Above: of the shots fired from in here, the share that fly
## high, over the part (decided as each is fired: bullet.gd): only those can
## hit someone on it; the rest fly low, under it, and only those can hit
## someone underneath it (watch_tower.gd passes_by()).

## How far out from the part's middle this section reaches.
@export_range(0.0, 60.0, 0.5, "suffix:m") var radius_m := 5.0
## Shot at from this far away, this share of the shots gets through the part
## to someone on it (the rest stop in its steel).
@export_range(0, 100, 1, "suffix:%") var pass_through := 50
## Seen Checked: enemies this far away can see you over height class 1 and 2
## cover (never over cover higher than this part's height class).
## Seen Unchecked: height class 1 and 2 cover can hide you, the same as on the
## ground. Height class 3 cover always hides you.
@export var seen := true
## Of the shots fired from this far away, the share that go above (can hit
## someone on the part, pass over anyone under it); the rest go below.
@export_range(0, 100, 1, "suffix:%") var above := 50
