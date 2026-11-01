# Summarises a BattleSquares battle log (scripts/battle_log.gd, format 1).
#   awk -f .claude/skills/battle-log/summarize.awk logs/battle_log.txt
#   awk -v timeline=0 -f ...   leaves out the event timeline
# Per square: shots and where they went, hits, time in each state, holding
# fire; then things that look wrong; then a timeline of what each did.

BEGIN { FS = "\t"; if (timeline == "") timeline = 1; STILL_S = 3.0 }

/^#/ { next }

{ t = $1 + 0; code = $2; if (t > tend) tend = t }

code == "U" {
	id = $3; side[id] = $4; name[id] = $5; born[id] = t; ids[++nids] = id
	sides[$4]++
	next
}

code == "M" {
	o = $3; kind[o] = $4; cls[o] = $9; next
}

code == "~" {
	id = $3
	for (i = 4; i <= NF; i++) {
		split($i, kv, "="); k = kv[1]; v = kv[2]
		if (k == "state") {
			if (id in state) {
				spent[id, state[id]] += t - since[id]
				check_still(id, t)
			}
			if (!((id, v) in spent)) { spent[id, v] = 0; slist[id] = slist[id] " " v }
			state[id] = v; since[id] = t; lastP[id] = t
			ev(t, id, "state " v)
		} else if (k == "target") {
			if (v != "-") { targets[id]++; ev(t, id, "target " v) }
		} else if (k == "alert" && v == "1") {
			alerted[id] = t; ev(t, id, "alerted")
		} else if (k == "dead") {
			died[id] = t; ev(t, id, "DIED")
		} else if (k == "cover" && v != "-") {
			ev(t, id, "cover " v " (" kind[v] " class " cls[v] ")")
		} else if (k == "hide") {
			if (v == "PEEKING") peeks[id]++
			if (v == "HIDING" || v == "PEEKING") incover[id] = 1
		} else if (k == "standoff" || k == "blocked") {
			if (v == "1") {
				on[id, k] = t
				if (k == "standoff") ev(t, id, "standoff: holding fire, all foes dug in")
			} else if ((id, k) in on) {
				held[id, k] += t - on[id, k]; delete on[id, k]
				if (k == "standoff") ev(t, id, "standoff over")
			}
		} else if (k == "stop" && v == "1") {
			ev(t, id, "told to stop")
		}
	}
	next
}

code == "P" { lastP[$3] = t; next }

code == "F" {
	s = $3; by = $4; shooter[s] = by; aimed[s] = $5; shots[by]++; next
}

code == "X" {
	s = $3; r = $4; by = shooter[s]
	if (by == "") next
	if (r ~ /^[0-9]+$/) {
		if (same_side(by, r)) { ff[by]++; ev(t, by, "FRIENDLY FIRE hit " r) }
		else hit[by]++
	} else if (r ~ /^o/) {
		intocover[by]++
		if (cls[r] == 3) heavy[by]++
	} else miss[by]++
	next
}

code == "H" { taken[$3]++; next }

code == "O" {
	orders[$3]++
	o_txt = $4; for (i = 5; i <= NF; i++) o_txt = o_txt " " $i
	ev(t, $3, "ORDER " o_txt)
	next
}

function same_side(a, b) {
	return (side[a] == "enemy") == (side[b] == "enemy")
}

# A unit that's meant to be on the move (or getting into cover) but hasn't
# had a position line for STILL_S: stood still, probably stuck.
function check_still(id, now,    gap) {
	if (state[id] != "MOVE" && state[id] != "FOLLOW" && state[id] != "ATTENTION" && state[id] != "BUILD") return
	gap = now - lastP[id]
	if (gap >= STILL_S) flag[++nflags] = sprintf("%7.2f  %s stood still %.1f s while %s (stuck?)", now, who(id), gap, state[id])
}

function who(id) { return id " (" side[id] " " name[id] ")" }

function ev(tt, id, what) {
	if (timeline) events[++nev] = sprintf("%7.2f  %-3s %-6s %s", tt, id, side[id], what)
}

END {
	printf "BATTLE LOG SUMMARY: %.1f s, ", tend
	for (sd in sides) printf "%d %s  ", sides[sd], sd
	print ""
	for (i = 1; i <= nids; i++) {
		id = ids[i]
		end_t = (id in died) ? died[id] : tend
		if (id in state) { spent[id, state[id]] += end_t - since[id]; check_still(id, end_t) }
		for (k in on) { split(k, p, SUBSEP); if (p[1] == id) held[id, p[2]] += end_t - on[k] }
		if (id in died) dead_side[side[id]]++
	}
	printf "Killed: "
	for (sd in sides) printf "%d of %d %s  ", dead_side[sd] + 0, sides[sd], sd
	print "\n"

	print "id  side    shots  hit-foe  friendly  into-cover(cl3)  ground/spent  hits-taken  died    standoff-s  blocked-s  targets  orders  peeks"
	for (i = 1; i <= nids; i++) {
		id = ids[i]
		printf "%-3s %-7s %5d  %7d  %8d  %6d (%3d)     %8d     %8d    %-7s %7.1f  %9.1f  %7d  %6d  %5d\n", id, side[id], shots[id], hit[id], ff[id],
			intocover[id], heavy[id], miss[id], taken[id], (id in died) ? sprintf("%.1f", died[id]) : "-",
			held[id, "standoff"], held[id, "blocked"], targets[id], orders[id], peeks[id]
	}
	print "\nTime in each state (s):"
	for (i = 1; i <= nids; i++) {
		id = ids[i]
		n = split(slist[id], sl, " ")
		line = ""
		for (j = 1; j <= n; j++) line = line sprintf("%s %.1f  ", sl[j], spent[id, sl[j]])
		printf "  %-3s %-6s %s\n", id, side[id], line
	}

	print "\nLooks wrong (check these against the timeline):"
	for (i = 1; i <= nids; i++) {
		id = ids[i]
		if (ff[id]) flag[++nflags] = sprintf("         %s hit its own side %d times", who(id), ff[id])
		if (shots[id] >= 10 && hit[id] == 0) flag[++nflags] = sprintf("         %s fired %d shots, hit nobody", who(id), shots[id])
		if (heavy[id] >= 5) flag[++nflags] = sprintf("         %s put %d of %d shots into class 3 cover", who(id), heavy[id], shots[id])
		if (side[id] == "enemy" && (id in alerted) && shots[id] == 0 && !(id in died)) flag[++nflags] = sprintf("         %s was alerted but never fired", who(id))
		if (((id, "SURPRISED") in spent) && !(id in incover)) flag[++nflags] = sprintf("         %s was SURPRISED but never got into cover", who(id))
		alive_s = ((id in died) ? died[id] : tend) - born[id]
		if (targets[id] >= 8 && targets[id] / (alive_s > 1 ? alive_s : 1) > 1)
			flag[++nflags] = sprintf("         %s changed target %d times in %.0f s (flip-flopping?)", who(id), targets[id], alive_s)
		if (held[id, "blocked"] > 10) flag[++nflags] = sprintf("         %s held fire %.0f s for someone in its line of fire", who(id), held[id, "blocked"])
	}
	if (nflags == 0) print "  nothing obvious"
	for (i = 1; i <= nflags; i++) print "  " flag[i]

	if (timeline) {
		print "\nTimeline (state, target, cover, alert, orders, deaths; P/F/X/H lines left out):"
		for (i = 1; i <= nev; i++) print events[i]
	}
}
