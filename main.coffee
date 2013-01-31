canvas = document.body.appendChild document.createElement 'canvas'
ctx = canvas.getContext '2d'

FONT = 'bold 12px "Menlo", "Consolas"'
MGN = 4

initial_data = { pads: {
  1: { lines: ['#!/bin/sh','','echo hello, world'], left:0, top:0, width:80, name:'hi.sh' }
  2: { lines: ['express = require "express"','','app = express()', '','app.use express.static __dirname', 'app.use express.logger()', '', 'app.listen 3000'], left:600, top:40, width:80, name:'serve.coffee' }
} }
cursors = {1:{line:0,char:0},2:{line:0,char:0}}

sharedoc = null
sharejs.open 'workspace', 'json', (err, doc) ->
  sharedoc = doc
  if doc.created
    doc.submitOp {p:[],od:null,oi:initial_data}
  doc.on 'change', (op) ->
    for c in op
      if c.si? or c.sd?
        char = c.p[c.p.length-1]
        line = c.p[c.p.length-2]
        id = c.p[1]
        if cursors[id].line is line
          if cursors[id].char > char
            if c.si?
              cursors[id].char += c.si.length
            else if c.sd?
              cursors[id].char -= c.sd.length
    repositionCursor p for p,_ of cursors
    draw()
  window.onresize()
  draw()

ctx.font = FONT
metrics = (->
  div = document.createElement 'div'
  div.style.font = FONT
  div.style.padding = div.style.margin = 0
  div.textContent = '#'
  div.style.display = 'inline-block'
  document.body.appendChild div
  rect = div.getBoundingClientRect()
  div.parentNode.removeChild div
  { width: rect.width, height: rect.height }
)()

offset = {x:-600,y:-200,scale:1}
focused = null

drawPending = false
draw = ->
  return if drawPending
  drawPending = true
  webkitRequestAnimationFrame ->
    drawPending = false
    ctx.clearRect 0, 0, canvas.width, canvas.height
    ctx.font = FONT
    ctx.textBaseline = 'top'
    ctx.save()
    ctx.translate canvas.width/2, canvas.height/2
    ctx.scale 1/offset.scale, 1/offset.scale
    ctx.translate offset.x, offset.y
    for id, p of sharedoc.snapshot.pads
      ctx.save()
      ctx.translate p.left, p.top
      ctx.fillStyle = 'lightgrey'
      ctx.fillText p.name, 0, metrics.height*-1-MGN
      ctx.fillStyle = 'hsla(0,10%,90%,0.8)'
      ctx.fillRect -MGN, -MGN, p.width*metrics.width+MGN*2, p.lines.length*metrics.height+MGN*2
      ctx.strokeStyle = if id is focused then 'black' else 'lightgray'
      ctx.lineWidth = 2
      ctx.strokeRect -MGN, -MGN, p.width*metrics.width+MGN*2, p.lines.length*metrics.height+MGN*2
      if id is focused
        ctx.fillStyle = 'red'
        w = if mode is insert then 2 else metrics.width
        ctx.fillRect cursors[id].char*metrics.width, cursors[id].line*metrics.height, w, metrics.height
      ctx.fillStyle = 'black'
      for l,i in p.lines
        ctx.fillText l, 0, metrics.height*i
      ctx.restore()
    ctx.restore()

repositionCursor = (p) ->
  moveTo p, cursors[p].line, cursors[p].char
moveTo = (p, line, char) ->
  doc = sharedoc.snapshot.pads[p]
  cursors[p].line = Math.max 0, Math.min doc.lines.length-1, line
  cursors[p].char = Math.max 0, Math.min doc.lines[cursors[p].line].length-1, char
move = (p, dy, dx) ->
  if dx is 0
    moveTo p, cursors[p].line + dy, (cursors[p].default_char ?= cursors[p].char)
  else
    moveTo p, cursors[p].line + dy, cursors[p].char + dx
    cursors[p].default_char = cursors[p].char
char = (p, c) ->
  sharedoc.submitOp {p:['pads',p,'lines',cursors[p].line,cursors[p].char], si:c}
  move p, 0, 1
deleteCharAt = (p, line, char) ->
  if char >= sharedoc.snapshot.pads[p].lines[line].length
    return
  sharedoc.submitOp {p:['pads',p,'lines',line,char], sd:sharedoc.snapshot.pads[p].lines[line].charAt(char)}

mode = null
window.onkeypress = (e) ->
  mode.press e
window.onkeydown = (e) ->
  mode.down? e
normal =
  press: (e) ->
    c = String.fromCharCode e.charCode
    if focused
      switch c
        when 'h'
          move focused, 0, -1
        when 'l'
          move focused, 0, 1
        when 'j'
          move focused, 1, 0
        when 'k'
          move focused, -1, 0
        when 'i'
          mode = insert
        when 'x'
          deleteCharAt focused, cursors[focused].line, cursors[focused].char
        when '$'
          moveTo focused, cursors[focused].line, Infinity
          p.cursor.default_char = Infinity
      draw()
insert =
  down: (e) ->
    if e.which is 27
      mode = normal
    draw()
  press: (e) ->
    kc = e.keyCode
    if 32 <= kc <= 127
      char focused, String.fromCharCode kc
    draw()
    
mode = normal

window.onmousewheel = (e) ->
  e.preventDefault()
  if e.metaKey
    offset.scale += e.wheelDeltaY*0.01
    offset.scale = Math.min 10, Math.max 1, offset.scale
  else
    offset.x += Math.round e.wheelDeltaX*0.5*offset.scale*0.5
    offset.y += Math.round e.wheelDeltaY*0.5*offset.scale*0.5
  draw()
  return false

within = (x, y, pad) ->
  pad.left-MGN <= x <= pad.left+pad.width*metrics.width+MGN and
    pad.top-MGN <= y <= pad.top+pad.lines.length*metrics.height+MGN

worldForClientXY = (cx, cy) ->
  x: (cx - canvas.width/2)*offset.scale - offset.x
  y: (cy - canvas.height/2)*offset.scale - offset.y
padForClientXY = (cx,cy) ->
  {x, y} = worldForClientXY cx, cy
  for id, p of sharedoc.snapshot.pads
    if within x, y, p
      return id
  return

window.addEventListener 'mouseup', click = (e) ->
  if (p = padForClientXY e.clientX, e.clientY) isnt focused
    focused = p
    draw()

window.onmousedown = (e) ->
  held = null
  heldAt = null
  mousemove = (e) ->
    loc = worldForClientXY e.clientX, e.clientY
    left = loc.x - heldAt.x
    top = loc.y - heldAt.y
    sharedoc.submitOp [
      {p:['pads',held,'left'],od:sharedoc.snapshot.pads[held].left, oi:left}
      {p:['pads',held,'top'],od:sharedoc.snapshot.pads[held].top, oi:top}
    ]
    draw()
  mouseup = (e) ->
    document.documentElement.classList.remove 'moving'
    window.removeEventListener 'mousemove', mousemove
    window.removeEventListener 'mouseup', mouseup
    window.removeEventListener 'blur', mouseup
    window.addEventListener 'mouseup', click
  dragmove = (e) ->
    offset.x += (e.clientX - heldAt.x)*offset.scale
    offset.y += (e.clientY - heldAt.y)*offset.scale
    heldAt.x = e.clientX
    heldAt.y = e.clientY
    draw()
  dragup = (e) ->
    document.documentElement.classList.remove 'moving'
    window.removeEventListener 'mousemove', dragmove
    window.removeEventListener 'mouseup', dragup
    window.removeEventListener 'blur', dragup
    window.addEventListener 'mouseup', click
  if e.metaKey
    held = padForClientXY e.clientX, e.clientY
    if held
      pointHeld = worldForClientXY e.clientX, e.clientY
      {left, top} = sharedoc.snapshot.pads[held]
      heldAt = {x:pointHeld.x-left, y:pointHeld.y-top}
      document.documentElement.classList.add 'moving'
      window.addEventListener 'mousemove', mousemove
      window.addEventListener 'mouseup', mouseup
      window.addEventListener 'blur', mouseup
      window.removeEventListener 'mouseup', click
    else
      heldAt = {x:e.clientX,y:e.clientY}
      document.documentElement.classList.add 'moving'
      window.addEventListener 'mousemove', dragmove
      window.addEventListener 'mouseup', dragup
      window.addEventListener 'blur', dragup
      window.removeEventListener 'mouseup', click

(window.onresize = ->
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight
  draw()
)()
