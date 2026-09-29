#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$repo_root" node <<'NODE'
const fs=require("fs"),vm=require("vm"),path=require("path"),assert=require("assert");
const root=process.env.REPO_ROOT;
const src=fs.readFileSync(path.join(root,"services/PopupAnchorPolicy.js"),"utf8");
const ctx={};vm.createContext(ctx);vm.runInContext(src,ctx);
assert.equal(ctx.normalize("com.openai.ChatGPT.desktop"),"comopenaichatgpt");
assert(ctx.matchScore("chatgpt","com.openai.ChatGPT")>0);
assert(ctx.matchScore("code","com.visualstudio.code")===0,"short suffixes must not collide");
assert(ctx.matchScore("com.discordapp.Discord","discord")>0);
assert.equal(ctx.kindPriority("tray"),300);
assert(ctx.kindPriority("tray")>ctx.kindPriority("bar"));
assert(ctx.kindPriority("bar")>ctx.kindPriority("dock"));
assert(ctx.placementScore(300,1000,"","DP-1")
    > ctx.placementScore(200,1000,"","DP-1"),
    "without source output, surface-kind precedence stays tray > dock");
assert(ctx.placementScore(200,1000,"DP-2","DP-2")
    > ctx.placementScore(300,1000,"DP-2","DP-1"),
    "same-output dock beats a mirrored tray on another output");
assert(ctx.placementScore(300,1000,"DP-2","DP-2")
    > ctx.placementScore(200,1000,"DP-2","DP-2"),
    "same-output surface-kind precedence still applies");
console.log("confirmation popup anchor identity/output policy: ok");
NODE
