import {isOpen} from "./jobs.mjs"

export function parseKey(key) {
    const i = key.indexOf(":")
    return {kind: key.slice(0, i), id: Number(key.slice(i + 1))}
}

export function openRowKeys(o) {
    const keys = o.pending.map(p => "reading:" + p.id)
    const shownInGroup = {}
    for (const j of o.jobs) {
        if (!isOpen(j)) continue
        if (!j.groupId) {
            keys.push("job:" + j.id)
            continue
        }
        if (shownInGroup[j.groupId] === undefined) {
            shownInGroup[j.groupId] = 0
            keys.push("group:" + j.groupId)
        }
        if (!o.collapsed[j.groupId] && shownInGroup[j.groupId] < o.playlistRows) {
            shownInGroup[j.groupId]++
            keys.push("job:" + j.id)
        }
    }
    return {keys: keys.slice(0, o.maxRows), hidden: Math.max(0, keys.length - o.maxRows)}
}

export function syncModel(model, keys) {
    const wanted = {}
    for (const k of keys) wanted[k] = true
    for (let i = model.count - 1; i >= 0; i--) {
        if (!wanted[model.get(i).key]) model.remove(i)
    }
    for (let j = 0; j < keys.length; j++) {
        if (j < model.count && model.get(j).key === keys[j]) continue
        let from = -1
        for (let m = j + 1; m < model.count; m++) {
            if (model.get(m).key === keys[j]) {
                from = m
                break
            }
        }
        if (from >= 0) model.move(from, j, 1)
        else model.insert(j, {key: keys[j]})
    }
}
