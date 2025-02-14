window.RactiveNetTangoBuilder = Ractive.extend({

  data: () -> {
    playMode:        false,        # Boolean
    newModel:        undefined,    # String
    lastCss:         "",           # String
    extraCssIsDirty: false,        # Boolean
    popupMenu:       undefined,    # RactivePopupMenu
    blockEditor: {
      show:        false,          # Boolean
      spaceNumber: undefined,      # Integer
      blockNumber: undefined,      # Integer
      submitEvent: undefined,      # String
      submitLabel: "Add New Block" # String
    },

    findElement:   () ->, # (String)  => Element
    createElement: () ->, # (String)  => Element
    appendElement: () ->, # (Element) => Unit

    extraCss: "",         # String
    title: "Blank Model", # String

    netTangoToggles: {
      workspaceBelow: {
        label: "Show NetTango spaces below the NetLogo model",
        checked: true
      }
    },

    tabOptions: {
      commandCenterTab: {
        label: "Hide command center tab",
        checked: true,
        checkedCssBuild:  'div.netlogo-tab-area > label:nth-of-type(1) { background: #eee; }',
        checkedCssExport: 'div.netlogo-tab-area > label:nth-of-type(1) { display: none; }'
      },
      codeTab: {
        label: "Hide code tab",
        checked: true,
        checkedCssBuild:  'div.netlogo-tab-area > label:nth-of-type(2) { background: #eee; }',
        checkedCssExport: 'div.netlogo-tab-area > label:nth-of-type(2) { display: none; }'
      },
      infoTab: {
        label: "Hide info tab",
        checked: true,
        checkedCssBuild:  'div.netlogo-tab-area > label:nth-of-type(3) { background: #eee; }',
        checkedCssExport: 'div.netlogo-tab-area > label:nth-of-type(3) { display: none; }'
      },
      speedBar: {
        label: "Hide model speed bar",
        checked: true,
        checkedCssBuild:  '.netlogo-speed-slider { background: #eee; }',
        checkedCssExport: '.netlogo-speed-slider { display: none; }'
      },
      fileButtons: {
        label: "Hide file and export buttons",
        checked: true,
        checkedCssBuild:  '.netlogo-export-wrapper { background: #eee; }',
        checkedCssExport: '.netlogo-export-wrapper { display: none; }'
      },
      authoring: {
        label: "Hide authoring unlock toggle",
        checked: true,
        checkedCssBuild:  '#authoring-lock { background: #eee; }',
        checkedCssExport: '#authoring-lock { display: none; }'
      },
      tabsPosition: {
        label: "Hide commands and code position toggle",
        checked: true,
        checkedCssBuild:  '#tabs-position { background: #eee; }',
        checkedCssExport: '#tabs-position { display: none; }'
      },
      poweredBy: {
        label: "Hide 'Powered by NetLogo' link",
        checked: false,
        checkedCssBuild:  '.netlogo-powered-by { background: #eee; }',
        checkedCssExport: '.netlogo-powered-by { display: none; }'
      }
    }
  }

  on: {

    # (Context) => Unit
    'ntb-refresh-css': (_) ->
      @refreshCss()
      return

    # (Context) => Boolean
    'ntb-clear-all-check': ({ event: { pageX, pageY } }) ->
      clearMenu = {
        name: "_",
        items: [
          {
            name: 'Are you sure?',
            items: [
              { name: 'Yes, clear all data', eventName: 'ntb-clear-all' }
            ]
          }
        ]
      }
      @get('popupMenu').popup(this, pageX, pageY, clearMenu)
      return false

    # (Context) => Unit
    '*.ntb-clear-all': (_) ->
      blankData = {
          code:       @get('newModel')
        , spaces:     []
        , extraCss:   ""
        , title:      "Blank Model"
        , netTangoToggles: {
          workspaceBelow: true
        }
        , tabOptions: {
            commandCenterTab: true
          , codeTab:          true
          , infoTab:          true
          , speedBar:         true
          , fileButtons:      true
          , authoring:        true
          , poweredBy:        false
        }
      }
      @load(blankData)
      return

    # (Context) => Unit
    'ntb-create-blockspace': (_) ->
      defsComponent = @findComponent('tangoDefs')
      defsComponent.createSpace({ defs: { blocks: [] } })
      return

  }

  observe: {
    "netTangoToggles.workspaceBelow.checked": (workspaceBelow) ->
      @moveSpaces(workspaceBelow, @get('playMode'))
  }

  # () => Unit
  checkForDirtyCss: () ->
    lastCss  = @get('lastCss')
    extraCss = @get('extraCss')
    @set('extraCssIsDirty', lastCss isnt extraCss)
    return

  # () => NetTangoBuilderData
  getNetTangoBuilderData: () ->
    spaces = @findComponent('tangoDefs').get('spaces')

    netTangoToggles = { }
    netTangoToggleValues = @get('netTangoToggles')
    Object.getOwnPropertyNames(netTangoToggleValues)
      .forEach((n) -> netTangoToggles[n] = netTangoToggleValues[n].checked)

    tabOptions = { }
    tabOptionValues = @get('tabOptions')
    Object.getOwnPropertyNames(tabOptionValues)
      .forEach((n) -> tabOptions[n] = tabOptionValues[n].checked)

    {
        spaces,
      , netTangoToggles
      , tabOptions
      , title:    @get('title')
      , extraCss: @get('extraCss')
    }

  # () => String
  getEmptyNetTangoProcedures: () ->
    spaces = @findComponent('tangoDefs').get('spaces')
    spaceProcs = for _, space of spaces
      space.defs.blocks.filter((b) => b.type is 'nlogo:procedure').map((b) => b.format + "\nend").join("\n")
    spaceProcs.join("\n")

  # (Boolean) => Unit
  moveSpaces: (workspaceBelow, playMode) ->
    # The main wrapper for the builder lives outside Ractive,
    # so we imperatively update the CSS classes instead of
    # using a template.  -Jeremy B July 2019
    content = document.getElementById('builder-content')
    options = document.getElementById('nettango-options')
    if (workspaceBelow)
      content.classList.remove('netlogo-display-horizontal')
      options.style.minWidth = ""
    else
      content.classList.add('netlogo-display-horizontal')
      if (playMode)
        options.style.minWidth = "auto"

  # () => Unit
  refreshCss: () ->
    # We use a fancy "CSS Injection" technique to get styles applied to the model iFrame - JMB August 2018
    styleElement = @get('findElement')('ntb-injected-style')

    if (not styleElement)
      styleElement    = @get('createElement')('style')
      styleElement.id = 'ntb-injected-style'
      @get('appendElement')(styleElement)

    extraCss = @get('extraCss')
    @set('lastCss', extraCss)
    @set('extraCssIsDirty', false)

    styleElement.innerHTML = @compileCss(@get('playMode'), extraCss)
    return

  # (Boolean, String) => String
  compileCss: (forExport, extraCss) ->
    tabOptions = @get('tabOptions')

    newCss = Object.getOwnPropertyNames(tabOptions)
      .filter( (prop) -> tabOptions[prop].checked and tabOptions[prop].checkedCssBuild isnt '' )
      .map( (prop) -> if (forExport) then tabOptions[prop].checkedCssExport else tabOptions[prop].checkedCssBuild )

    newCss = newCss.concat([
      extraCss,
      # Override the rounded corners of tabs to make them easier to hide with CSS and without JS - JMB August 2018
      '.netlogo-tab:first-child { border-radius: 0px; }',
      '.netlogo-tab:last-child, .netlogo-tab-content:last-child { border-radius: 0px; border-bottom-width: 1px; }',
      '.netlogo-tab { border: 1px solid rgb(36, 36, 121); }',
      '.netlogo-tab-area { margin: 0px; }'
    ])

    newCss.join('\n')

  # (NetTangoBuilderData) => Unit
  load: (ntData) ->
    defsComponent = @findComponent('tangoDefs')
    defsComponent.set('spaces', [])
    for spaceVals in (ntData.spaces ? [])
      defsComponent.createSpace(spaceVals)
    defsComponent.updateCode(true)

    netTangoToggles = @get('netTangoToggles')
    for key, prop of (ntData.netTangoToggles ? { })
      if netTangoToggles.hasOwnProperty(key)
        @set("netTangoToggles.#{key}.checked", prop)

    tabOptions = @get('tabOptions')
    for key, prop of (ntData.tabOptions ? { })
      if tabOptions.hasOwnProperty(key)
        @set("tabOptions.#{key}.checked", prop)

    for propName in [ 'extraCss' ]
      if ntData.hasOwnProperty(propName)
        @set(propName, ntData[propName])

    if (ntData.code?)
      @fire('ntb-model-change', ntData.title, ntData.code)
    else
      @fire('ntb-model-change', "New Model", @get('newModel'))

    @refreshCss()

    # If this was an import, clear the value so we can re-import the same file in Chrome and Safari - JMB August 2018
    importInput = @find('#ntb-import-json')
    if importInput?
      importInput.value = ''

    return

  components: {
      tangoDefs:    RactiveNetTangoSpaces
    , errorDisplay: RactiveErrorDisplay
  }

  template:
    # coffeelint: disable=max_line_length
    """
    <div class="ntb-container" style="position: relative;">
      <errorDisplay></errorDisplay>

      <div class="ntb-controls">
        {{# !playMode }}
        <div class="ntb-block-defs-controls">
          <button class="ntb-button" type="button" on-click="ntb-create-blockspace" >Add New Block Space</button>
          <button class="ntb-button" type="button" on-click="ntb-save" >Save NetTango Progress</button>
          <button class="ntb-button" type="button" on-click="ntb-export-page" >Export NetTango Page</button>
          <button id="clear-all-button" class="ntb-button" type="button" on-click="ntb-clear-all-check" >Clear Model and Spaces</button>
          <button class="ntb-button" on-click="ntb-export-json" type="button">Export NetTango JSON</button>
          <label class="ntb-file-label">Import NetTango JSON<input id="ntb-import-json" class="ntb-file-button" type="file" on-change="ntb-import-json" ></label>
        </div>
        {{/}}

        <tangoDefs id="ntb-defs" playMode={{ playMode }} popupMenu={{ popupMenu }} />

        {{# !playMode }}
        <div class="netlogo-display-horizontal">
          <ul style-list-style="none">
          {{#tabOptions:key }}<li>
            <input id="ntb-{{ key }}" type="checkbox" name="{{ key }}" checked="{{ checked }}" on-change="@this.refreshCss()">
            <label for="ntb-{{ key }}">{{ label }}</label>
          </li>{{/tabOptions }}
          </ul>
          <ul style-list-style="none">
          {{#netTangoToggles:key }}<li>
            <input id="ntb-{{ key }}" type="checkbox" name="{{ key }}" checked="{{ checked }}">
            <label for="ntb-{{ key }}">{{ label }}</label>
          </li>{{/netTangoToggles }}
          </ul>
        </div>
          <div class="ntb-block-defs-controls">
            <label for="ntb-extra-css">Extra CSS to include</label>
            <button class="ntb-button" type="button" on-click="ntb-refresh-css"{{# !extraCssIsDirty }} disabled{{/}}>Refresh Model Styles</button>
          </div>
          <textarea id="ntb-extra-css" type="text" on-change-keyup-paste="@this.checkForDirtyCss()" value="{{ extraCss }}" ></textarea>
          <style id="ntb-injected-css" type="text/css">{{ computedCss }}</style>
        {{/}}
      </div>
    </div>
    """
    # coffeelint: enable=max_line_length
})
