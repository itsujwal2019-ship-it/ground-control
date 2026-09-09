const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// Colors must match PLAYER_COLORS in key_spawner.gd
const COLORS = [
  [1.0, 0.2, 0.2 ],  // Red
  [0.2, 0.5,  1.0],  // Blue
  [0.2, 0.85, 0.2],  // Green
  [1.0, 0.85, 0.1],  // Yellow
  [0.7, 0.2,  1.0],  // Purple
];

// rooms: code -> { players: Map<id, ws>, colorMap: Map<id, colorIndex>, usedColors: Set, host: id }
const rooms = new Map();
let nextId = 1;

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}

function broadcast(room, data, excludeId = null) {
  for (const [id, ws] of room.players) {
    if (id !== excludeId) send(ws, data);
  }
}

function makeCode() {
  let code;
  do { code = Math.random().toString(36).slice(2, 6).toUpperCase(); } while (rooms.has(code));
  return code;
}

wss.on('connection', (ws) => {
  const pid = String(nextId++);
  ws.pid = pid;
  ws.roomCode = null;

  send(ws, { type: 'connected', id: pid });

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    switch (msg.type) {

      case 'create_room': {
        const code = makeCode();
        rooms.set(code, {
          players:    new Map([[pid, ws]]),
          colorMap:   new Map([[pid, 0]]),
          usedColors: new Set([0]),
          host:       pid,
          paused:     false,
          pauseTimer: null,
        });
        ws.roomCode = code;
        send(ws, { type: 'room_created', code, color: COLORS[0] });
        break;
      }

      case 'join_room': {
        const code = (msg.code || '').toUpperCase();
        const room = rooms.get(code);
        if (!room)                { send(ws, { type: 'error', message: 'Room not found.' }); return; }
        if (room.players.size >= 5) { send(ws, { type: 'error', message: 'Room is full.' });  return; }

        let ci = 0;
        while (room.usedColors.has(ci)) ci++;
        room.usedColors.add(ci);
        room.players.set(pid, ws);
        room.colorMap.set(pid, ci);
        ws.roomCode = code;

        const existing = [];
        for (const [id, idx] of room.colorMap) {
          if (id !== pid) existing.push({ id, color: COLORS[idx] });
        }
        send(ws, { type: 'room_joined', code, color: COLORS[ci], players: existing });
        broadcast(room, { type: 'player_joined', id: pid, color: COLORS[ci] }, pid);
        break;
      }

      case 'start_game': {
        const room = rooms.get(ws.roomCode);
        if (!room || room.host !== pid) return;
        const payload = { type: 'game_start', seed: msg.seed ?? Math.floor(Math.random() * 99999) };
        broadcast(room, payload);
        send(ws, payload);
        break;
      }

      case 'pause': {
        const room = rooms.get(ws.roomCode);
        if (!room || room.paused) return;
        room.paused = true;
        broadcast(room, { type: 'paused', by: pid });  // send to ALL including pauser
        room.pauseTimer = setTimeout(() => {
          if (!room.paused) return;
          room.paused = false;
          room.pauseTimer = null;
          broadcast(room, { type: 'resumed' });
        }, 20000);
        break;
      }

      case 'resume': {
        const room = rooms.get(ws.roomCode);
        if (!room || !room.paused) return;
        clearTimeout(room.pauseTimer);
        room.pauseTimer = null;
        room.paused = false;
        broadcast(room, { type: 'resumed' });
        break;
      }

      // Positional / game-state messages — just forward with sender id
      case 'move':
      case 'key_collected':
      case 'win': {
        const room = rooms.get(ws.roomCode);
        if (room) broadcast(room, { ...msg, id: pid }, pid);
        break;
      }
    }
  });

  ws.on('close', () => {
    const room = rooms.get(ws.roomCode);
    if (!room) return;
    const ci = room.colorMap.get(pid);
    room.players.delete(pid);
    room.colorMap.delete(pid);
    room.usedColors.delete(ci);
    broadcast(room, { type: 'player_left', id: pid });
    if (room.players.size === 0) {
      if (room.pauseTimer) clearTimeout(room.pauseTimer);
      rooms.delete(ws.roomCode);
    } else if (room.host === pid) {
      room.host = room.players.keys().next().value;  // promote oldest remaining player
    }
  });
});

console.log(`Ground Control relay listening on port ${PORT}`);
