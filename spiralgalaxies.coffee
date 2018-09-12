boxWidth = 1
boxHeight = 1

edgeWidth = 0.2
centerRadius = 0.6

#undoSpeed = 250
#
#neighborCoords = ([x,y]) ->
#  [
#    [x-1, y]
#    [x+1, y]
#    [x, y-1]
#    [x, y+1]
#  ]

add = (u,v) -> [u[0] + v[0], u[1] + v[1]]
sub = (u,v) -> [u[0] - v[0], u[1] - v[1]]
perp = (v) -> [-v[1], v[0]]
neg = (v) -> [-v[0], -v[1]]
double = (v) -> [2*v[0], 2*v[1]]
half = (v) -> [v[0]/2, v[1]/2]
equal = (u,v) -> u[0] == v[0] and u[1] == v[1]

parseCoord = (coord) ->
  [x, y] = coord.split ","
  x = parseFloat x
  y = parseFloat y
  [x, y]

edge2dir = (edge) ->
  [
    edge[0] - Math.floor edge[0]
    edge[1] - Math.floor edge[1]
  ]

parseASCII = (ascii) ->
  centers = []
  solution = {}
  width = 0
  for row, y in ascii.split '\n'
    width = Math.max width, (row.length-1) / 2
    for char, x in row
      char = char.toLowerCase()
      if char in ['w', 'b']
        centers.push
          x: x / 2
          y: y / 2
          color: char
      else if char in ['-', '|']
        solution[[x/2,y/2]] = true
  height = (y-1) / 2
  regions = computeRegions width, height, centers, solution
  [width, height, centers, solution, regions]
parseCache = {}

computeRegions = (width, height, centers, edges) ->
  centerMap = {}
  for center in centers
    centerMap[[center.x, center.y]] = center
  obstacles = {}
  for edge of edges
    edge = parseCoord edge
    dir = edge2dir edge
    obstacles[edge] = true
    obstacles[add edge, dir] = true
    obstacles[sub edge, dir] = true
  faces = []
  visited = {}
  for edge of edges
    edge = parseCoord edge
    makeFace = (v1, v2) =>
      return if [v1,v2] of visited
      v0 = v1
      face = [v0]
      center = null
      turn = 0
      until equal v2, v0
        visited[[v1,v2]] = true
        face.push v2
        straight = sub v2, v1
        left = perp straight
        for start in [v2, add v1, half straight]
          here = add start, half left
          while here not of obstacles and
                0 <= here[0] <= width and 0 <= here[1] <= height
            if here of centerMap
              center = centerMap[here]
              break
            here = add here, half left
        if (add v2, half left) of edges
          turn -= 1
          dir = left
        else
          if (add v2, half straight) of edges
            dir = straight
          else
            turn += 1
            dir = neg left
            unless (add v2, half dir) of edges
              throw new Error "No way to go from #{v3}"
        v3 = add v2, dir
        [v1, v2] = [v2, v3]
      visited[[v1,v2]] = true
      ## Skip incorrectly oriented faces: outside face and hole boundaries
      unless turn > 0
        faces.push
          vertices: face
          center: center
          color: center?.color ? 'invalid'
    dir = edge2dir edge
    v1 = sub edge, dir
    v2 = add edge, dir
    makeFace v1, v2
    makeFace v2, v1
  faces

checkRegionSymmetry = (region) ->
  vertexMap = {}
  for vertex in region.vertices
    vertexMap[vertex] = 1
  unless region.center
    console.warn "missing center"
    return true
  for vertex in region.vertices
    center = [region.center.x, region.center.y]
    symmetric = add center, neg sub vertex, center
    vertexMap[symmetric] += 1
  for vertex, count of vertexMap
    if count != 2
      console.log count
      return false
  true

class SpiralGalaxies
  constructor: (@svg, @width, @height, @centers, @solution, @regions) ->
    if @svg
      @regionGroup = @svg.group()
      .addClass 'regions'
      @gridGroup = @svg.group()
      .addClass 'grid'
      @centersGroup = @svg.group()
      .addClass 'centers'
      @edgesGroup = @svg.group()
      .addClass 'edges'
    @sizeChange()
    @centersChange()
    @regionsChange()

  #toASCII: ->
  #  (for y in [0...@height]
  #    (for x in [0...@width]
  #      if @coinAt [x,y]
  #        'o'
  #      else
  #        '-'
  #    ).join ''
  #  ).join '\n'

  sizeChange: ->
    return unless @svg?
    @gridGroup.clear()
    for x in [0..@width]
      @gridGroup.line x, 0, x, @height
    for y in [0..@height]
      @gridGroup.line 0, y, @width, y
    @gridGroup.rect @width, @height

    @svg.viewbox
      x: -edgeWidth/2
      y: -edgeWidth/2
      width: @width + edgeWidth
      height: @height + edgeWidth

  centersChange: ->
    return unless @svg?
    @centersGroup.clear()
    @centerMap = {}
    for center, i in @centers
      center.circle =
      @centersGroup.circle centerRadius
      .center center.x, center.y
      .addClass center.color
      #.attr 'data-center', i
      @centerMap[[center.x, center.y]] = center

  regionsChange: ->
    return unless @svg?
    @regionGroup.clear()
    if @regions.length != @centers.length
      console.log "#{@regions.length} regions but #{@centers.length} centers"
    for region in @regions
      @regionGroup.polygon region.vertices
      .addClass region.color
      @edgesGroup.polygon region.vertices
      .addClass region.color

class SpiralGalaxiesPuzzle extends SpiralGalaxies
  constructor: (args...) ->
    super args...
    if @svg
      @userGroup = @svg.group()
      .addClass 'user'
      @regionGroup.opacity 0
    @highlightEnable()

  highlightEnable: ->
    @state = {}
    @lines = {}
    rt2o2 = Math.sqrt(2)/2
    @highlight = @svg.rect rt2o2, rt2o2
    .center 0, 0
    .rotate 45
    .addClass 'target'
    .opacity 0
    event2coord = (e) =>
      pt = @svg.point e.clientX, e.clientY
      rotated =
        x: rt2o2 * (pt.x + pt.y)
        y: rt2o2 * (-pt.x + pt.y)
      rotated.x /= rt2o2
      rotated.y /= rt2o2
      rotated.x -= 0.5
      rotated.y -= 0.5
      rotated.x = Math.round rotated.x
      rotated.y = Math.round rotated.y
      rotated.x += 0.5
      rotated.y += 0.5
      rotated.x *= rt2o2
      rotated.y *= rt2o2
      coord = [
        0.5 * Math.round 2 * rt2o2 * (rotated.x - rotated.y)
        0.5 * Math.round 2 * rt2o2 * (rotated.x + rotated.y)
      ]
      if 0 < coord[0] < @width and 0 < coord[1] < @height
        coord
      else
        null
    @svg.mousemove (e) =>
      edge = event2coord e
      if edge?
        @highlight.translate edge...
        .opacity 0.333
      else
        @highlight.opacity 0
    @svg.on 'mouseleave', (e) =>
      @highlight.opacity 0
    #for x in [0.5...@width] by 0.5
    #  for y in [0...@height-0.5] by 0.5
    #    if (x+y) - Math.floor(x+y) < 0.1
    #      @targetsGroup.rect rt2o2, rt2o2
    #      .rotate 45
    #      .translate x, y
    @svg.click (e) =>
      edge = event2coord e
      return unless edge?
      @click edge

  click: (edge, links = true) ->
    if @lines[edge]?
      @lines[edge].remove()
      @lines[edge] = undefined
    dir = edge2dir edge
    @state[edge] =
      switch @state[edge]
        when undefined
          unless @centerMap[edge]
            true
          else
            false
        when true
          false
        when false
          undefined
    if @state[edge] == false and
       not document.getElementById('connectors').checked
      @state[edge] = undefined
    if @state[edge]?
      if @state[edge] == false
        dir = perp dir
      p = sub edge, dir
      q = add edge, dir
      @lines[edge] = @userGroup.line p..., q...
      .attr 'class', @state[edge].toString()
    if @solved()
      unless @regionGroup.opacity() == 1
        @regionGroup.animate().opacity 1
    else
      unless @regionGroup.opacity() == 0
        @regionGroup.animate().opacity 0

    if @linked? and links
      for link in @linked when link != @
        link.click edge, false

  solved: ->
    for edge of @solution
      parsed = parseCoord edge
      continue unless 0 < parsed[0] < @width and 0 < parsed[1] < @height
      if @state[edge] != true
        console.log edge, 'mismatch'
        return false
    for edge, truth of @state
      continue unless truth == true
      if @solution[edge] != true
        console.log edge, 'Mismatch'
        return false
    console.log 'SOLVED'
    true

## Based on jolly.exe's code from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
getParameterByName = (name, search = location.search) ->
  name = name.replace /[\[]/g, "\\["
             .replace /[\]]/g, "\\]"
  regex = new RegExp "[\\?&]#{name}=([^&#]*)"
  results = regex.exec search
  return null unless results?
  decodeURIComponent results[1].replace /\+/g, " "

## Based on meouw's answer on http://stackoverflow.com/questions/442404/retrieve-the-position-x-y-of-an-html-element
getOffset = (el) ->
  x = y = 0
  while el and not isNaN(el.offsetLeft) and not isNaN(el.offsetTop)
    x += el.offsetLeft - el.scrollLeft
    y += el.offsetTop - el.scrollTop
    el = el.offsetParent
  x: x
  y: y

## FONT GUI

resize = (ids) ->
  offset = getOffset document.getElementById ids[0]
  height = Math.max 100, window.innerHeight - offset.y
  for id in ids
    document.getElementById(id).style.height = "#{height}px"

radioButtons = [
  options: ['puzzle', 'solved']
  default: 'puzzle'
]
checkboxes = ['puzzle', 'solved', 'connectors']
checkboxesRebuild = ['puzzle', 'solved']

fontLoadState = ->
  for checkbox in checkboxes
    document.getElementById(checkbox).checked = getParameterByName checkbox
  for radio in radioButtons
    if (true for key in radio.options when document.getElementById(key).checked).length == 0
      document.getElementById(radio.default).checked = true
  text = getParameterByName('text') ? 'text'
  document.getElementById('text').value = text
  updateText false

old = {}
updateText = (setUrl = true, force = false) ->
  params =
    text: (document.getElementById('text').value
           .replace(/\r\n/g, '\r').replace(/\r/g, '\n'))
  classes = []
  for checkbox in checkboxes
    params[checkbox] = document.getElementById(checkbox).checked
    if params[checkbox]
      classes.push checkbox
  document.getElementById('output').setAttribute 'class', classes.join ' '
  size = document.getElementById('size').value
  while document.getElementById('svgSize').sheet.cssRules.length > 0
    document.getElementById('svgSize').sheet.deleteRule 0
  document.getElementById('svgSize').sheet.insertRule(
    "svg { width: #{0.9*size}px; margin: #{size*0.05}px; }", 0)
  document.getElementById('svgSize').sheet.insertRule(
    ".word + .word { margin-left: #{0.4*size}px; }", 1)
  checkParams =
    text: params.text
  for checkbox in checkboxesRebuild
    checkParams[checkbox] = params[checkbox]
  setState params if setUrl
  return if (true for key of checkParams when checkParams[key] == old[key]).length == (key for key of checkParams).length and not force
  old = checkParams

  Box =
    if params['puzzle']
      SpiralGalaxiesPuzzle
    else
      SpiralGalaxies

  charBoxes = {}
  output = document.getElementById 'output'
  output.innerHTML = '' ## clear previous children
  for line in params.text.split '\n'
    output.appendChild outputLine = document.createElement 'p'
    outputLine.setAttribute 'class', 'line'
    outputLine.appendChild outputWord = document.createElement 'span'
    outputWord.setAttribute 'class', 'word'
    for char, c in line
      char = char.toUpperCase()
      if char of window.font
        letter = window.font[char]
        parseCache[letter] ?= parseASCII letter
        svg = SVG outputWord
        box = new Box svg, parseCache[letter]...
        charBoxes[char] ?= []
        charBoxes[char].push box
        box.linked = charBoxes[char]
      else if char == ' '
        #space = document.createElement 'span'
        #space.setAttribute 'class', 'space'
        #outputLine.appendChild space
        outputLine.appendChild outputWord = document.createElement 'span'
        outputWord.setAttribute 'class', 'word'
      else
        console.log "Unknown character '#{char}'"

setState = (params) ->
  encoded =
    for key, value of params
      if value == true
        value = '1'
      else if value == false or value == ''
        continue
      key + '=' + encodeURIComponent(value).replace /%20/g, '+'
  history.replaceState null, 'text',
    "#{document.location.pathname}?#{encoded.join '&'}"

fontResize = ->
  document.getElementById('size').max =
    document.getElementById('size').scrollWidth - 30 - 2
                                              # - circle width - border width

fontGui = ->
  updateTextSoon = (event) ->
    setTimeout updateText, 0
    true
  for event in ['input', 'propertychange', 'keyup']
    document.getElementById('text').addEventListener event, updateTextSoon
  for event in ['input', 'propertychange', 'click']
    for checkbox in checkboxes
      document.getElementById(checkbox).addEventListener event, updateTextSoon
  for event in ['input', 'propertychange', 'click']
    document.getElementById('size').addEventListener event, updateTextSoon

  document.getElementById('reset').addEventListener 'click', ->
    updateText false, true

  window.addEventListener 'popstate', fontLoadState
  fontLoadState()
  window.addEventListener 'resize', fontResize
  fontResize()

## GUI MAIN

window?.onload = ->
  if document.getElementById 'text'
    fontGui()
  #else if document.getElementById 'startsvg'
  #  puzzleGui()

## FONT CHECKER

main = ->
  font = require('./font').font
  for char, ascii of font
    continue if char == 'grid'
    console.log char
    [width, height, centers, solution, regions] = parseASCII ascii
    for region in regions
      unless checkRegionSymmetry region
        console.error "#{char} has asymmetric region! [#{region.vertices.join ' '}] centered at #{region.center.x},#{region.center.y}"

main() if require? and require.main == module