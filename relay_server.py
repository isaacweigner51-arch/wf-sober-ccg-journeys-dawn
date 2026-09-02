#!/usr/bin/env python3
"""WF Sober CCG private-match relay.
Run: python3 relay_server.py --host 0.0.0.0 --port 8765
For remote phones, expose this port through a TLS reverse proxy or tunnel and use wss://URL in the game.
"""
import argparse, asyncio, json, random, string
import websockets

rooms = {}
clients = {}

def code():
    while True:
        c = ''.join(random.choice(string.digits) for _ in range(6))
        if c not in rooms: return c

async def send(ws, obj):
    await ws.send(json.dumps(obj))

async def broadcast(room, obj, exclude=None):
    for ws in list(room['players']):
        if ws != exclude:
            try: await send(ws, obj)
            except Exception: pass

async def lobby(room_code):
    r=rooms.get(room_code)
    if not r: return
    await broadcast(r, {"type":"lobby","room":room_code,"players":len(r['players']),"ready":len(r['ready'])})

async def maybe_start(room_code):
    r=rooms.get(room_code)
    if not r or len(r['players']) != 2 or len(r['ready']) != 2: return
    seed=random.randint(1, 2_000_000_000)
    host, join = r['players'][0], r['players'][1]
    hc=r['classes'].get(host,'Hope'); jc=r['classes'].get(join,'Courage')
    await send(host,{"type":"match_start","room":room_code,"role":"host","your_class":hc,"opponent_class":jc,"seed":seed})
    await send(join,{"type":"match_start","room":room_code,"role":"join","your_class":jc,"opponent_class":hc,"seed":seed})

async def cleanup(ws):
    info=clients.pop(ws,None)
    if not info:return
    rc=info.get('room'); r=rooms.get(rc)
    if not r:return
    if ws in r['players']:r['players'].remove(ws)
    r['ready'].discard(ws); r['mulligan'].discard(ws)
    await broadcast(r,{"type":"game","event":"opponent_left"})
    if not r['players']:rooms.pop(rc,None)
    else:await lobby(rc)

async def handler(ws):
    clients[ws]={}
    try:
        async for raw in ws:
            try: m=json.loads(raw)
            except Exception: continue
            t=m.get('type')
            if t=='create_room':
                rc=code(); rooms[rc]={"players":[ws],"ready":set(),"mulligan":set(),"classes":{ws:m.get('class','Hope')}}
                clients[ws]={"room":rc,"role":"host"}; await send(ws,{"type":"room_created","room":rc}); await lobby(rc)
            elif t=='join_room':
                rc=str(m.get('room','')).upper(); r=rooms.get(rc)
                if not r: await send(ws,{"type":"error","message":"Room not found."}); continue
                if len(r['players'])>=2: await send(ws,{"type":"error","message":"Room is full."}); continue
                r['players'].append(ws); r['classes'][ws]=m.get('class','Courage'); clients[ws]={"room":rc,"role":"join"}
                await send(ws,{"type":"room_joined","room":rc}); await lobby(rc)
            elif t=='ready':
                rc=clients.get(ws,{}).get('room'); r=rooms.get(rc)
                if r:
                    r['classes'][ws]=m.get('class',r['classes'].get(ws,'Hope')); r['ready'].add(ws); await lobby(rc); await maybe_start(rc)
            elif t=='mulligan_done':
                rc=clients.get(ws,{}).get('room'); r=rooms.get(rc)
                if r:
                    r['mulligan'].add(ws)
                    await broadcast(r,{"type":"game","event":"snapshot","state":m.get('state',{})},exclude=ws)
                    if len(r['mulligan'])==2:
                        await broadcast(r,{"type":"game","event":"battle_begin","first_role":"host"})
            elif t=='game':
                rc=clients.get(ws,{}).get('room'); r=rooms.get(rc)
                if r: await broadcast(r,m,exclude=ws)
    finally:
        await cleanup(ws)

async def main(host,port):
    print(f"WF Sober CCG relay listening on ws://{host}:{port}")
    async with websockets.serve(handler,host,port,max_size=8_000_000):
        await asyncio.Future()

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--host',default='0.0.0.0'); p.add_argument('--port',type=int,default=8765); a=p.parse_args()
    asyncio.run(main(a.host,a.port))
