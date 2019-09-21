window.RactiveNetTangoSpaces = Ractive.extend({

  data: () -> {
    playMode:         false, # Boolean
    spaces:           [],    # Array[NetTangoSpace]
    lastCompiledCode: "",    # String
    codeIsDirty:      false, # Boolean
    popupMenu:        null,  # RactivePopupMenu
    blockEditForm:    null   # RactiveNetTangoBlockForm
  }

  on: {

    # (Context) => Unit
    'complete': (_) ->
      blockEditForm = @findComponent('blockEditForm')
      @set('blockEditForm', blockEditForm)
      @observe('spaces', (spaces) ->
        spaces.forEach( (space, i) ->
          space.id      = i
          space.spaceId = "ntb-defs-#{i}"
        )
      )
      return

    # (Context, String, Boolean) => Unit
    '*.ntb-code-changed': (_, isInitialLoad) ->
      @updateCode(isInitialLoad)
      return

    # (Context, Integer) => Unit
    '*.ntb-delete-blockspace': (_, spaceNumber) ->
      spaces = @get('spaces')
      newSpaces = spaces.filter( (s) -> s.id isnt spaceNumber )
      newSpaces.forEach( (s, i) ->
        s.id      = i
        s.spaceId = "ntb-defs-#{i}"
      )
      @set('spaces', newSpaces)
      @updateCode(false)
      return

    '*.ntb-recompile-start': (_) ->
      @recompile()
  }

  # (Boolean) => Unit
  updateCode: (isInitialLoad) ->
    lastCode    = @get('lastCode')
    newCode     = @assembleCode(addSpaceNames = false)
    codeIsDirty = lastCode isnt newCode
    @set('codeIsDirty', codeIsDirty)
    @set('code', @assembleCode(addSpaceNames = true))
    if codeIsDirty
      @set('lastCode', newCode)
      if not isInitialLoad
        @fire('ntb-code-dirty')
    return

  # () => Unit
  recompile: () ->
    ntbCode = @assembleCode(addSpaceNames = false)
    @fire('ntb-recompile', ntbCode)
    @set('lastCode', ntbCode)
    @set('codeIsDirty', false)
    return

  # () => Unit
  assembleCode: (addSpaceNames) ->
    spaces = @get('spaces')
    spaceCodes =
      spaces.map( (space) ->
        if addSpaceNames
          "; Code for #{space.name}\n#{space.netLogoCode ? ""}".trim()
        else
          (space.netLogoCode ? "").trim()
      )
    spaceCodes.join("\n\n")

  # () => Array[NetTangoExpressionOperator]
  expressionDefaults: () ->
    return [
      { name: "true",  type: "bool" },
      { name: "false", type: "bool" },
      { name: "AND",   type: "bool", arguments: [ "bool", "bool"],  format: "({0} and {1})" },
      { name: "OR",    type: "bool", arguments: [ "bool", "bool" ], format: "({0} or {1})" },
      { name: "NOT",   type: "bool", arguments: [ "bool"],          format: "(not {0})" },
      { name: ">",     type: "bool", arguments: [ "num", "num" ] },
      { name: ">=",    type: "bool", arguments: [ "num", "num" ] },
      { name: "<",     type: "bool", arguments: [ "num", "num" ] },
      { name: "<=",    type: "bool", arguments: [ "num", "num" ] },
      { name: "!=",    type: "bool", arguments: [ "num", "num" ] },
      { name: "=",     type: "bool", arguments: [ "num", "num" ] },
      { name: "+",     type: "num",  arguments: [ "num", "num"] },
      { name: "-",     type: "num",  arguments: [ "num", "num"] },
      { name: "×",     type: "num",  arguments: [ "num", "num"], format: "({0} * {1})" },
      { name: "/",     type: "num",  arguments: [ "num", "num"] },
      { name: "random", type: "num", arguments: [ "num" ], format: "random-float {0}" }
    ]

  # (NetTangoSpace) => NetTangoSpace
  createSpace: (spaceVals) ->
    spaces  = @get('spaces')
    id      = spaces.length
    spaceId = "ntb-defs-#{id}"
    defs    = if spaceVals.defs? then spaceVals.defs else { blocks: [], program: { chains: [] } }
    defs.expressions = defs.expressions ? @expressionDefaults()
    space = {
        id:              id
      , spaceId:         spaceId
      , name:            "Block Space #{id}"
      , width:           430
      , height:          500
      , defs:            defs
      , defsJson:        JSON.stringify(defs, null, '  ')
      , defsJsonChanged: false
    }
    for propName in [ 'name', 'width', 'height' ]
      if(spaceVals.hasOwnProperty(propName))
        space[propName] = spaceVals[propName]

    @push('spaces', space)
    return space

  components: {
    tangoSpace:    RactiveNetTangoSpace
    blockEditForm: RactiveNetTangoBlockForm
  }

  template:
    # coffeelint: disable=max_line_length
    """
    <blockEditForm idBasis="ntb-block" parentClass="ntb-container" verticalOffset="10" />

    <div class="ntb-block-defs-list">
      {{#spaces:spaceNum }}
        <tangoSpace
          space="{{ this }}"
          playMode="{{ playMode }}"
          popupMenu="{{ popupMenu }}"
          blockEditForm="{{ blockEditForm }}"
          codeIsDirty="{{ codeIsDirty }}"
        />
      {{/spaces }}
    </div>
    <label for="ntb-code">NetLogo Code</label>
    <textarea id="ntb-code" readOnly>{{ code }}</textarea>
    """
    # coffeelint: enable=max_line_length
})
