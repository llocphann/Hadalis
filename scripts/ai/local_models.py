#!/usr/bin/env python3
"""Finite GGUF inventory. Never download or load a model while scanning."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

def roots():
    override=os.environ.get('INIR_GGUF_ROOTS')
    if override is not None:
        return [Path(p).expanduser() for p in json.loads(override)[:8]]
    home=Path.home()
    hub=Path(os.environ.get('HUGGINGFACE_HUB_CACHE',str(Path(os.environ.get('HF_HOME',str(home/'.cache/huggingface')))/'hub')))
    return [hub,home/'.unsloth/studio/exports',home/'.unsloth/studio/library',home/'Models',
        home/'.local/share/inir/models',home/'Downloads']

def runtime():
    candidates=[shutil.which('llama-server'),str(Path.home()/'.unsloth/llama.cpp/llama-server'),
        str(Path.home()/'.unsloth/llama.cpp/build/bin/llama-server')]
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate,os.X_OK):return str(Path(candidate).resolve())
    return ''

def thinking_capable(name):
    value=str(name).casefold()
    return bool(re.search(r'(^|[^a-z0-9])qwen3(?:[.\\-_]|$)',value)) or 'gpt-oss' in value or 'deepseek-r1' in value

def valid_file(path):
    try:
        if path.stat().st_size<20*1024*1024:return False
        with path.open('rb') as f:header=f.read(24)
        magic,version,tensors,metadata=struct.unpack('<4sIQQ',header)
        return magic==b'GGUF' and version in (2,3) and 0<tensors<1000000 and 0<metadata<1000000
    except (OSError,ValueError,struct.error):return False

def inventory(search_roots=None):
    entries=[];seen=set();visited=0
    for root in search_roots if search_roots is not None else roots():
        root=Path(root).expanduser()
        if not root.is_dir():continue
        for directory,dirs,files in os.walk(root,followlinks=False):
            visited+=len(dirs)+len(files)
            if visited>12000:break
            depth=len(Path(directory).relative_to(root).parts)
            dirs[:]=sorted(d for d in dirs if depth<6 and d not in ('blobs','.git','node_modules','.venv','build','target','.locks'))
            for name in sorted(files):
                if not name.lower().endswith('.gguf') or name.lower().startswith(('mmproj','ggml-vocab')):continue
                link=Path(directory)/name
                if not valid_file(link):continue
                path=link.resolve();identity=str(path)
                if identity in seen:continue
                seen.add(identity)
                projector=next((p for p in sorted(link.parent.glob('mmproj*.gguf')) if valid_file(p)),None)
                quant=re.search(r'(UD-)?(?:IQ|Q|F|BF)\d[\w_]*$',link.stem,re.I)
                entries.append({'id':'gguf:'+hashlib.sha256(identity.encode()).hexdigest()[:20],
                    'name':link.stem[:160],'path':str(link.absolute()),'size':path.stat().st_size,
                    'quantization':quant[0] if quant else '',
                    'projector':str(projector.absolute()) if projector else '',
                    'thinking':thinking_capable(link.stem),
                    'source':'Unsloth' if 'unsloth' in str(link).lower() else 'GGUF'})
                if len(entries)>=32:break
            if len(entries)>=32:break
        if visited>12000 or len(entries)>=32:break
    return {'models':entries,'runtimePath':runtime(),'scanned':visited}

if __name__=='__main__':
    try:print(json.dumps(inventory(),separators=(',',':')))
    except (OSError,ValueError,TypeError):print(json.dumps({'models':[],'runtimePath':'','error':'Model inventory unavailable'}))
